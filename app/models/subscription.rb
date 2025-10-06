class Subscription < ApplicationRecord
  belongs_to :user

  # Subscription statuses from Stripe
  STATUSES = %w[
    incomplete
    incomplete_expired
    trialing
    active
    past_due
    canceled
    unpaid
  ].freeze

  # Platform subscription plans
  PLANS = {
    'free' => { name: 'Free', price: 0, stripe_price_id: nil },
    'pro' => { name: 'Pro', price: 1900, stripe_price_id: -> { Rails.application.credentials.dig(:stripe, :pro_price_id) } },
    'enterprise' => { name: 'Enterprise', price: 9900, stripe_price_id: -> { Rails.application.credentials.dig(:stripe, :enterprise_price_id) } }
  }.freeze

  # Validations
  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_customer_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :plan, presence: true, inclusion: { in: PLANS.keys }
  validates :user_id, uniqueness: { scope: :status, conditions: -> { where(status: %w[active trialing]) },
                                     message: 'already has an active subscription' }

  # Scopes
  scope :active, -> { where(status: %w[active trialing]) }
  scope :canceled, -> { where(status: 'canceled') }
  scope :past_due, -> { where(status: 'past_due') }
  scope :by_plan, ->(plan) { where(plan: plan) }
  scope :expiring_soon, -> { active.where('current_period_end < ?', 7.days.from_now) }

  # Callbacks
  after_save :sync_user_subscription_tier
  after_destroy :reset_user_subscription_tier

  # Instance methods
  def active?
    %w[active trialing].include?(status)
  end

  def trialing?
    status == 'trialing'
  end

  def canceled?
    status == 'canceled'
  end

  def past_due?
    status == 'past_due'
  end

  def days_until_renewal
    return nil unless current_period_end
    ((current_period_end - Time.current) / 1.day).to_i
  end

  def cancel!
    return false if canceled?

    stripe_subscription = Stripe::Subscription.update(
      stripe_subscription_id,
      { cancel_at_period_end: true }
    )

    update!(
      cancel_at_period_end: true,
      canceled_at: Time.current
    )
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to cancel subscription: #{e.message}")
    false
  end

  def reactivate!
    return false unless cancel_at_period_end

    stripe_subscription = Stripe::Subscription.update(
      stripe_subscription_id,
      { cancel_at_period_end: false }
    )

    update!(
      cancel_at_period_end: false,
      canceled_at: nil
    )
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to reactivate subscription: #{e.message}")
    false
  end

  def plan_name
    PLANS.dig(plan, :name) || plan.titleize
  end

  def plan_price_cents
    PLANS.dig(plan, :price) || 0
  end

  def plan_price_dollars
    plan_price_cents / 100.0
  end

  private

  def sync_user_subscription_tier
    return unless saved_change_to_status? || saved_change_to_plan?

    if active?
      user.update_column(:subscription_tier, plan)
    elsif canceled? || past_due?
      user.update_column(:subscription_tier, 'free')
    end
  end

  def reset_user_subscription_tier
    user.update_column(:subscription_tier, 'free')
  end
end
