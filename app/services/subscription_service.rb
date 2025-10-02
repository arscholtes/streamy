# Service for handling Stripe subscription operations
class SubscriptionService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Create a Stripe Checkout Session for subscription
  def create_checkout_session(plan:, success_url:, cancel_url:)
    raise ArgumentError, "Invalid plan" unless Subscription::PLANS.key?(plan)
    raise ArgumentError, "Plan must be pro or enterprise" if plan == 'free'

    price_id = Subscription::PLANS.dig(plan, :stripe_price_id)
    raise ArgumentError, "Stripe price ID not configured for #{plan}" unless price_id

    # Get or create Stripe customer
    customer_id = get_or_create_customer

    session = Stripe::Checkout::Session.create({
      customer: customer_id,
      mode: 'subscription',
      line_items: [{
        price: price_id,
        quantity: 1
      }],
      success_url: success_url,
      cancel_url: cancel_url,
      allow_promotion_codes: true,
      subscription_data: {
        metadata: {
          user_id: user.id,
          plan: plan
        }
      },
      metadata: {
        user_id: user.id,
        plan: plan
      }
    })

    session
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe checkout error: #{e.message}")
    raise
  end

  # Create subscription from successful checkout
  def create_subscription_from_stripe(stripe_subscription)
    Subscription.create!(
      user: user,
      stripe_subscription_id: stripe_subscription.id,
      stripe_customer_id: stripe_subscription.customer,
      status: stripe_subscription.status,
      plan: stripe_subscription.metadata['plan'],
      current_period_start: Time.at(stripe_subscription.current_period_start),
      current_period_end: Time.at(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end,
      trial_start: stripe_subscription.trial_start ? Time.at(stripe_subscription.trial_start) : nil,
      trial_end: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil
    )
  end

  # Update subscription from Stripe webhook
  def update_subscription_from_stripe(stripe_subscription)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)
    return unless subscription

    subscription.update!(
      status: stripe_subscription.status,
      current_period_start: Time.at(stripe_subscription.current_period_start),
      current_period_end: Time.at(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end,
      canceled_at: stripe_subscription.canceled_at ? Time.at(stripe_subscription.canceled_at) : nil
    )
  end

  # Cancel subscription at period end
  def cancel_subscription
    subscription = user.active_subscription
    return false unless subscription

    subscription.cancel!
  end

  # Reactivate canceled subscription
  def reactivate_subscription
    subscription = user.subscriptions.where(cancel_at_period_end: true).first
    return false unless subscription

    subscription.reactivate!
  end

  # Change subscription plan
  def change_plan(new_plan)
    raise ArgumentError, "Invalid plan" unless Subscription::PLANS.key?(new_plan)

    subscription = user.active_subscription
    return false unless subscription

    new_price_id = Subscription::PLANS.dig(new_plan, :stripe_price_id)
    raise ArgumentError, "Stripe price ID not configured for #{new_plan}" unless new_price_id

    # Update subscription in Stripe
    stripe_subscription = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)

    Stripe::Subscription.update(
      stripe_subscription.id,
      {
        items: [{
          id: stripe_subscription.items.data[0].id,
          price: new_price_id
        }],
        proration_behavior: 'always_invoice',
        metadata: { plan: new_plan }
      }
    )

    # Update local subscription
    subscription.update!(plan: new_plan)

    true
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to change subscription plan: #{e.message}")
    false
  end

  # Create customer portal session for managing subscription
  def create_portal_session(return_url:)
    subscription = user.active_subscription || user.subscriptions.last
    return nil unless subscription

    session = Stripe::BillingPortal::Session.create({
      customer: subscription.stripe_customer_id,
      return_url: return_url
    })

    session
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to create portal session: #{e.message}")
    nil
  end

  private

  def get_or_create_customer
    # Return existing customer ID if user has one
    return user.stripe_customer_id if user.stripe_customer_id.present?

    # Check if user has existing subscription with customer ID
    if user.subscriptions.any?
      customer_id = user.subscriptions.last.stripe_customer_id
      user.update!(stripe_customer_id: customer_id)
      return customer_id
    end

    # Create new Stripe customer
    customer = Stripe::Customer.create({
      email: user.email,
      name: user.username,
      metadata: {
        user_id: user.id
      }
    })

    # Save customer ID to user
    user.update!(stripe_customer_id: customer.id)

    customer.id
  end
end
