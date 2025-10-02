class WebhooksController < ApplicationController
  # Skip CSRF verification for webhooks from Stripe
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login

  # POST /webhooks/stripe
  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    begin
      event = Stripe::Webhook.construct_event(
        payload,
        sig_header,
        Rails.configuration.stripe[:signing_secret]
      )
    rescue JSON::ParserError => e
      Rails.logger.error("Webhook JSON parsing error: #{e.message}")
      render json: { error: 'Invalid payload' }, status: :bad_request and return
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("Webhook signature verification failed: #{e.message}")
      render json: { error: 'Invalid signature' }, status: :bad_request and return
    end

    # Handle the event
    case event.type
    when 'checkout.session.completed'
      handle_checkout_completed(event.data.object)
    when 'customer.subscription.created'
      handle_subscription_created(event.data.object)
    when 'customer.subscription.updated'
      handle_subscription_updated(event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.data.object)
    when 'payment_intent.succeeded'
      handle_payment_succeeded(event.data.object)
    when 'payment_intent.payment_failed'
      handle_payment_failed(event.data.object)
    when 'invoice.payment_succeeded'
      handle_invoice_payment_succeeded(event.data.object)
    when 'invoice.payment_failed'
      handle_invoice_payment_failed(event.data.object)
    else
      Rails.logger.info("Unhandled webhook event type: #{event.type}")
    end

    render json: { received: true }, status: :ok
  end

  private

  def handle_checkout_completed(session)
    return unless session.mode == 'subscription'

    user = User.find_by(id: session.metadata.user_id)
    return unless user

    # Subscription will be created via customer.subscription.created event
    Rails.logger.info("Checkout completed for user #{user.id}, subscription: #{session.subscription}")
  end

  def handle_subscription_created(stripe_subscription)
    user = User.find_by(stripe_customer_id: stripe_subscription.customer)
    return unless user

    plan = determine_plan_from_stripe_subscription(stripe_subscription)

    subscription = user.subscriptions.create!(
      stripe_subscription_id: stripe_subscription.id,
      stripe_customer_id: stripe_subscription.customer,
      status: stripe_subscription.status,
      plan: plan,
      current_period_start: Time.at(stripe_subscription.current_period_start),
      current_period_end: Time.at(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end
    )

    Rails.logger.info("Created subscription #{subscription.id} for user #{user.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create subscription: #{e.message}")
  end

  def handle_subscription_updated(stripe_subscription)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)
    return unless subscription

    plan = determine_plan_from_stripe_subscription(stripe_subscription)

    subscription.update!(
      status: stripe_subscription.status,
      plan: plan,
      current_period_start: Time.at(stripe_subscription.current_period_start),
      current_period_end: Time.at(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end
    )

    Rails.logger.info("Updated subscription #{subscription.id}, status: #{subscription.status}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to update subscription: #{e.message}")
  end

  def handle_subscription_deleted(stripe_subscription)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)
    return unless subscription

    subscription.update!(
      status: 'canceled',
      canceled_at: Time.current
    )

    Rails.logger.info("Canceled subscription #{subscription.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to cancel subscription: #{e.message}")
  end

  def handle_payment_succeeded(payment_intent)
    # Handle one-time payments (donations, tips)
    return unless payment_intent.metadata.user_id

    user = User.find_by(id: payment_intent.metadata.user_id)
    return unless user

    recipient = User.find_by(id: payment_intent.metadata.recipient_id) if payment_intent.metadata.recipient_id

    payment_type = payment_intent.metadata.payment_type || 'donation'
    amount_cents = payment_intent.amount

    platform_fee = payment_intent.application_fee_amount || 0
    recipient_amount = amount_cents - platform_fee

    payment = user.payments.create!(
      stripe_payment_intent_id: payment_intent.id,
      stripe_charge_id: payment_intent.latest_charge,
      recipient: recipient,
      amount_cents: amount_cents,
      platform_fee_cents: platform_fee,
      recipient_amount_cents: recipient_amount,
      currency: payment_intent.currency,
      payment_type: payment_type,
      status: 'succeeded',
      paid_at: Time.current,
      metadata: payment_intent.metadata.to_h
    )

    Rails.logger.info("Created payment #{payment.id} for user #{user.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create payment: #{e.message}")
  end

  def handle_payment_failed(payment_intent)
    return unless payment_intent.metadata.user_id

    user = User.find_by(id: payment_intent.metadata.user_id)
    return unless user

    recipient = User.find_by(id: payment_intent.metadata.recipient_id) if payment_intent.metadata.recipient_id

    payment = user.payments.create!(
      stripe_payment_intent_id: payment_intent.id,
      recipient: recipient,
      amount_cents: payment_intent.amount,
      currency: payment_intent.currency,
      payment_type: payment_intent.metadata.payment_type || 'donation',
      status: 'failed',
      metadata: payment_intent.metadata.to_h
    )

    Rails.logger.info("Payment failed for user #{user.id}: #{payment_intent.last_payment_error&.message}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to log failed payment: #{e.message}")
  end

  def handle_invoice_payment_succeeded(invoice)
    return unless invoice.subscription

    subscription = Subscription.find_by(stripe_subscription_id: invoice.subscription)
    return unless subscription

    # Record the payment
    subscription.user.payments.create!(
      stripe_payment_intent_id: invoice.payment_intent,
      stripe_charge_id: invoice.charge,
      amount_cents: invoice.amount_paid,
      currency: invoice.currency,
      payment_type: 'subscription',
      status: 'succeeded',
      paid_at: Time.at(invoice.status_transitions.paid_at),
      metadata: { invoice_id: invoice.id, subscription_id: subscription.id }
    )

    Rails.logger.info("Recorded subscription payment for subscription #{subscription.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to record invoice payment: #{e.message}")
  end

  def handle_invoice_payment_failed(invoice)
    return unless invoice.subscription

    subscription = Subscription.find_by(stripe_subscription_id: invoice.subscription)
    return unless subscription

    Rails.logger.warn("Invoice payment failed for subscription #{subscription.id}")

    # Optionally send notification to user
    # UserMailer.payment_failed(subscription.user).deliver_later
  end

  def determine_plan_from_stripe_subscription(stripe_subscription)
    price_id = stripe_subscription.items.data.first&.price&.id

    Subscription::PLANS.each do |plan_key, plan_data|
      return plan_key if plan_data[:stripe_price_id] == price_id
    end

    'free' # Default fallback
  end
end
