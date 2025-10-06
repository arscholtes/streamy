# app/controllers/webhooks/stripe_controller.rb
module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_stripe_signature

    def create
      case @event.type
      when 'checkout.session.completed'
        handle_checkout_session_completed
      when 'customer.subscription.updated'
        handle_subscription_updated
      when 'customer.subscription.deleted'
        handle_subscription_deleted
      when 'invoice.payment_succeeded'
        handle_invoice_payment_succeeded
      when 'invoice.payment_failed'
        handle_invoice_payment_failed
      else
        Rails.logger.info "Unhandled Stripe event type: #{@event.type}"
      end

      render json: { status: 'success' }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Stripe webhook error: #{e.message}"
      render json: { error: e.message }, status: :bad_request
    end

    private

    def verify_stripe_signature
      payload = request.body.read
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']

      @event = Stripe::Webhook.construct_event(
        payload,
        sig_header,
        Rails.configuration.stripe[:webhook_secret]
      )
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON payload: #{e.message}"
      render json: { error: 'Invalid payload' }, status: :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Invalid signature: #{e.message}"
      render json: { error: 'Invalid signature' }, status: :bad_request
    end

    def handle_checkout_session_completed
      session = @event.data.object
      user = User.find_by(stripe_customer_id: session.customer)

      return unless user

      user.update(
        stripe_subscription_id: session.subscription,
        subscription_status: 'active',
        subscription_tier: determine_tier(session)
      )

      Rails.logger.info "Subscription activated for user #{user.id}"
    end

    def handle_subscription_updated
      subscription = @event.data.object
      user = User.find_by(stripe_subscription_id: subscription.id)

      return unless user

      user.update(
        subscription_status: subscription.status,
        current_period_end: Time.at(subscription.current_period_end),
        subscription_tier: determine_tier_from_subscription(subscription)
      )

      Rails.logger.info "Subscription updated for user #{user.id}: #{subscription.status}"
    end

    def handle_subscription_deleted
      subscription = @event.data.object
      user = User.find_by(stripe_subscription_id: subscription.id)

      return unless user

      user.update(
        subscription_status: 'canceled',
        subscription_tier: 'free',
        stripe_subscription_id: nil,
        current_period_end: nil
      )

      Rails.logger.info "Subscription canceled for user #{user.id}"
    end

    def handle_invoice_payment_succeeded
      invoice = @event.data.object
      user = User.find_by(stripe_customer_id: invoice.customer)

      return unless user

      user.update(subscription_status: 'active')
      Rails.logger.info "Payment succeeded for user #{user.id}"
    end

    def handle_invoice_payment_failed
      invoice = @event.data.object
      user = User.find_by(stripe_customer_id: invoice.customer)

      return unless user

      user.update(subscription_status: 'past_due')
      Rails.logger.error "Payment failed for user #{user.id}"
    end

    def determine_tier(session)
      # Determine tier based on price ID or metadata
      line_items = Stripe::Checkout::Session.list_line_items(session.id)
      price_id = line_items.data.first&.price&.id

      case price_id
      when Rails.application.credentials.dig(:stripe, :pro_price_id)
        'pro'
      when Rails.application.credentials.dig(:stripe, :enterprise_price_id)
        'enterprise'
      else
        'free'
      end
    end

    def determine_tier_from_subscription(subscription)
      price_id = subscription.items.data.first&.price&.id

      case price_id
      when Rails.application.credentials.dig(:stripe, :pro_price_id)
        'pro'
      when Rails.application.credentials.dig(:stripe, :enterprise_price_id)
        'enterprise'
      else
        'free'
      end
    end
  end
end
