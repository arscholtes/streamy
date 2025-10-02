class Payment < ApplicationRecord
  belongs_to :user
  belongs_to :recipient, class_name: 'User', optional: true

  # Payment types
  TYPES = %w[
    subscription
    donation
    tip
    channel_subscription
    refund
  ].freeze

  # Payment statuses
  STATUSES = %w[
    pending
    processing
    succeeded
    failed
    canceled
    refunded
  ].freeze

  # Validations
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payment_type, presence: true, inclusion: { in: TYPES }
  validates :stripe_payment_intent_id, uniqueness: true, allow_nil: true

  # Scopes
  scope :succeeded, -> { where(status: 'succeeded') }
  scope :failed, -> { where(status: 'failed') }
  scope :refunded, -> { where(status: 'refunded') }
  scope :by_type, ->(type) { where(payment_type: type) }
  scope :donations, -> { where(payment_type: 'donation') }
  scope :tips, -> { where(payment_type: 'tip') }
  scope :subscriptions, -> { where(payment_type: 'subscription') }
  scope :for_recipient, ->(recipient_id) { where(recipient_id: recipient_id) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def succeeded?
    status == 'succeeded'
  end

  def failed?
    status == 'failed'
  end

  def refunded?
    status == 'refunded'
  end

  def amount_dollars
    amount_cents / 100.0
  end

  def platform_fee_dollars
    platform_fee_cents / 100.0
  end

  def recipient_amount_dollars
    return nil unless recipient_amount_cents
    recipient_amount_cents / 100.0
  end

  def refund_amount_dollars
    return nil unless refund_amount_cents
    refund_amount_cents / 100.0
  end

  def can_refund?
    succeeded? && !refunded? && stripe_charge_id.present?
  end

  def refund!(amount_cents: nil)
    return false unless can_refund?

    refund_amount = amount_cents || self.amount_cents

    refund = Stripe::Refund.create({
      charge: stripe_charge_id,
      amount: refund_amount
    })

    update!(
      status: 'refunded',
      refunded_at: Time.current,
      refund_amount_cents: refund_amount
    )

    true
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to refund payment: #{e.message}")
    false
  end

  # Calculate platform fee (default 5%)
  def self.calculate_platform_fee(amount_cents, fee_percentage = 5.0)
    (amount_cents * (fee_percentage / 100.0)).to_i
  end

  # Calculate recipient amount after fee
  def self.calculate_recipient_amount(amount_cents, fee_cents)
    amount_cents - fee_cents
  end
end
