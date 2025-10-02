# Service for handling one-time payments (donations, tips)
class PaymentService
  attr_reader :payer, :recipient, :amount_cents, :payment_type

  def initialize(payer:, recipient: nil, amount_cents:, payment_type:)
    @payer = payer
    @recipient = recipient
    @amount_cents = amount_cents
    @payment_type = payment_type
  end

  # Create payment intent for donation/tip
  def create_payment_intent(description: nil, metadata: {})
    # Calculate platform fee and recipient amount
    platform_fee = Payment.calculate_platform_fee(amount_cents)
    recipient_amount = Payment.calculate_recipient_amount(amount_cents, platform_fee)

    # Build Stripe payment intent parameters
    intent_params = {
      amount: amount_cents,
      currency: 'usd',
      description: description || "#{payment_type.titleize} from #{payer.username}",
      metadata: metadata.merge({
        user_id: payer.id,
        payment_type: payment_type,
        recipient_id: recipient&.id
      }.compact)
    }

    # If recipient has Stripe Connect account, use application fee
    if recipient && recipient.stripe_account&.stripe_id.present?
      intent_params.merge!({
        application_fee_amount: platform_fee,
        transfer_data: {
          destination: recipient.stripe_account.stripe_id
        }
      })
    end

    # Create payment intent
    intent = Stripe::PaymentIntent.create(intent_params)

    # Create local payment record
    payment = Payment.create!(
      user: payer,
      recipient: recipient,
      stripe_payment_intent_id: intent.id,
      amount_cents: amount_cents,
      platform_fee_cents: platform_fee,
      recipient_amount_cents: recipient_amount,
      currency: 'usd',
      status: intent.status,
      payment_type: payment_type,
      description: description,
      metadata: metadata
    )

    { intent: intent, payment: payment }
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to create payment intent: #{e.message}")
    raise
  end

  # Update payment from webhook
  def self.update_from_stripe_event(payment_intent)
    payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
    return unless payment

    payment.update!(
      status: payment_intent.status,
      stripe_charge_id: payment_intent.latest_charge
    )

    # If succeeded and has recipient, record the transfer
    if payment_intent.status == 'succeeded' && payment.recipient.present?
      record_transfer(payment)
    end

    payment
  end

  # Record transfer to connected account
  def self.record_transfer(payment)
    return unless payment.recipient.present?
    return if payment.stripe_transfer_id.present?

    # Get the charge
    charge = Stripe::Charge.retrieve(payment.stripe_charge_id)

    # Record the transfer ID from charge
    if charge.transfer.present?
      payment.update!(stripe_transfer_id: charge.transfer)
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to record transfer: #{e.message}")
  end

  # Create refund
  def self.refund_payment(payment, amount_cents: nil)
    return false unless payment.can_refund?

    payment.refund!(amount_cents: amount_cents)
  end

  # Get payment statistics for user
  def self.user_stats(user, period: 30.days)
    payments = user.payments.where('created_at > ?', period.ago).succeeded

    {
      total_spent: payments.sum(:amount_cents),
      total_count: payments.count,
      by_type: payments.group(:payment_type).sum(:amount_cents)
    }
  end

  # Get earning statistics for streamer
  def self.streamer_earnings(streamer, period: 30.days)
    earnings = streamer.received_payments.where('created_at > ?', period.ago).succeeded

    {
      total_earned: earnings.sum(:recipient_amount_cents),
      total_count: earnings.count,
      by_type: earnings.group(:payment_type).sum(:recipient_amount_cents),
      platform_fees: earnings.sum(:platform_fee_cents)
    }
  end
end
