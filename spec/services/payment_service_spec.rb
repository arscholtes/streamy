require 'rails_helper'

RSpec.describe PaymentService, type: :service do
  let(:payer) { double('User', id: 1, username: 'payer_user', payments: double('ActiveRecord::Relation')) }
  let(:recipient) { double('User', id: 2, stripe_account: stripe_account, received_payments: double('ActiveRecord::Relation')) }
  let(:stripe_account) { double('StripeAccount', stripe_id: 'acct_123') }
  let(:service) { described_class.new(payer: payer, recipient: recipient, amount_cents: 1000, payment_type: 'donation') }

  before do
    allow(Payment).to receive(:calculate_platform_fee).and_return(50)
    allow(Payment).to receive(:calculate_recipient_amount).and_return(950)
  end

  describe '#initialize' do
    it 'sets the payer' do
      expect(service.payer).to eq(payer)
    end

    it 'sets the recipient' do
      expect(service.recipient).to eq(recipient)
    end

    it 'sets the amount_cents' do
      expect(service.amount_cents).to eq(1000)
    end

    it 'sets the payment_type' do
      expect(service.payment_type).to eq('donation')
    end
  end

  describe '#create_payment_intent' do
    let(:payment_intent) do
      double('Stripe::PaymentIntent',
        id: 'pi_123',
        status: 'requires_payment_method',
        client_secret: 'pi_123_secret'
      )
    end
    let(:payment) { double('Payment') }

    before do
      allow(Stripe::PaymentIntent).to receive(:create).and_return(payment_intent)
      allow(Payment).to receive(:create!).and_return(payment)
    end

    it 'calculates platform fee and recipient amount' do
      expect(Payment).to receive(:calculate_platform_fee).with(1000)
      expect(Payment).to receive(:calculate_recipient_amount).with(1000, 50)

      service.create_payment_intent
    end

    it 'creates Stripe payment intent with basic params' do
      expect(Stripe::PaymentIntent).to receive(:create).with(hash_including(
        amount: 1000,
        currency: 'usd',
        description: 'Donation from payer_user'
      ))

      service.create_payment_intent
    end

    it 'includes metadata with user_id, payment_type, and recipient_id' do
      expect(Stripe::PaymentIntent).to receive(:create).with(hash_including(
        metadata: hash_including(
          user_id: 1,
          payment_type: 'donation',
          recipient_id: 2
        )
      ))

      service.create_payment_intent
    end

    it 'includes custom description if provided' do
      expect(Stripe::PaymentIntent).to receive(:create).with(hash_including(
        description: 'Custom description'
      ))

      service.create_payment_intent(description: 'Custom description')
    end

    it 'merges custom metadata' do
      expect(Stripe::PaymentIntent).to receive(:create).with(hash_including(
        metadata: hash_including(
          user_id: 1,
          payment_type: 'donation',
          recipient_id: 2,
          custom_key: 'custom_value'
        )
      ))

      service.create_payment_intent(metadata: { custom_key: 'custom_value' })
    end

    context 'with recipient having Stripe Connect account' do
      it 'includes application fee and transfer data' do
        expect(Stripe::PaymentIntent).to receive(:create).with(hash_including(
          application_fee_amount: 50,
          transfer_data: { destination: 'acct_123' }
        ))

        service.create_payment_intent
      end
    end

    context 'without recipient or without Stripe account' do
      let(:service_no_recipient) { described_class.new(payer: payer, recipient: nil, amount_cents: 1000, payment_type: 'donation') }

      it 'does not include application fee or transfer data' do
        allow(Stripe::PaymentIntent).to receive(:create) do |params|
          expect(params).not_to have_key(:application_fee_amount)
          expect(params).not_to have_key(:transfer_data)
          payment_intent
        end

        service_no_recipient.create_payment_intent
      end
    end

    it 'creates local payment record' do
      expect(Payment).to receive(:create!).with(hash_including(
        user: payer,
        recipient: recipient,
        stripe_payment_intent_id: 'pi_123',
        amount_cents: 1000,
        platform_fee_cents: 50,
        recipient_amount_cents: 950,
        currency: 'usd',
        status: 'requires_payment_method',
        payment_type: 'donation'
      ))

      service.create_payment_intent
    end

    it 'returns payment intent and payment record' do
      result = service.create_payment_intent

      expect(result[:intent]).to eq(payment_intent)
      expect(result[:payment]).to eq(payment)
    end

    it 'logs and raises Stripe errors' do
      allow(Stripe::PaymentIntent).to receive(:create).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to create payment intent/)

      expect {
        service.create_payment_intent
      }.to raise_error(Stripe::StripeError)
    end
  end

  describe '.update_from_stripe_event' do
    let(:payment) { double('Payment', update!: true, recipient: recipient, stripe_charge_id: nil) }
    let(:payment_intent) do
      double('Stripe::PaymentIntent',
        id: 'pi_123',
        status: 'succeeded',
        latest_charge: 'ch_123'
      )
    end

    before do
      allow(Payment).to receive(:find_by).and_return(payment)
    end

    it 'finds payment by payment_intent_id' do
      expect(Payment).to receive(:find_by).with(stripe_payment_intent_id: 'pi_123')

      described_class.update_from_stripe_event(payment_intent)
    end

    it 'updates payment status and charge_id' do
      allow(described_class).to receive(:record_transfer)

      expect(payment).to receive(:update!).with(hash_including(
        status: 'succeeded',
        stripe_charge_id: 'ch_123'
      ))

      described_class.update_from_stripe_event(payment_intent)
    end

    it 'records transfer if payment succeeded and has recipient' do
      expect(described_class).to receive(:record_transfer).with(payment)

      described_class.update_from_stripe_event(payment_intent)
    end

    it 'does not record transfer if payment not succeeded' do
      allow(payment_intent).to receive(:status).and_return('pending')

      expect(described_class).not_to receive(:record_transfer)

      described_class.update_from_stripe_event(payment_intent)
    end

    it 'does not record transfer if no recipient' do
      allow(payment).to receive(:recipient).and_return(nil)

      expect(described_class).not_to receive(:record_transfer)

      described_class.update_from_stripe_event(payment_intent)
    end

    it 'returns nil if payment not found' do
      allow(Payment).to receive(:find_by).and_return(nil)

      result = described_class.update_from_stripe_event(payment_intent)

      expect(result).to be_nil
    end
  end

  describe '.record_transfer' do
    let(:payment) { double('Payment', stripe_charge_id: 'ch_123', stripe_transfer_id: nil, recipient: recipient, update!: true) }
    let(:charge) { double('Stripe::Charge', transfer: 'tr_123') }

    before do
      allow(Stripe::Charge).to receive(:retrieve).and_return(charge)
    end

    it 'retrieves charge from Stripe' do
      expect(Stripe::Charge).to receive(:retrieve).with('ch_123')

      described_class.record_transfer(payment)
    end

    it 'updates payment with transfer_id' do
      expect(payment).to receive(:update!).with(stripe_transfer_id: 'tr_123')

      described_class.record_transfer(payment)
    end

    it 'returns early if no recipient' do
      allow(payment).to receive(:recipient).and_return(nil)

      expect(Stripe::Charge).not_to receive(:retrieve)

      described_class.record_transfer(payment)
    end

    it 'returns early if transfer_id already set' do
      allow(payment).to receive(:stripe_transfer_id).and_return('tr_existing')

      expect(Stripe::Charge).not_to receive(:retrieve)

      described_class.record_transfer(payment)
    end

    it 'logs error on Stripe error' do
      allow(Stripe::Charge).to receive(:retrieve).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to record transfer/)

      expect {
        described_class.record_transfer(payment)
      }.not_to raise_error
    end
  end

  describe '.refund_payment' do
    let(:payment) { double('Payment', can_refund?: true, refund!: true) }

    it 'refunds payment if allowed' do
      expect(payment).to receive(:can_refund?)
      expect(payment).to receive(:refund!).with(amount_cents: nil)

      described_class.refund_payment(payment)
    end

    it 'passes amount_cents to refund!' do
      expect(payment).to receive(:refund!).with(amount_cents: 500)

      described_class.refund_payment(payment, amount_cents: 500)
    end

    it 'returns false if cannot refund' do
      allow(payment).to receive(:can_refund?).and_return(false)

      expect(payment).not_to receive(:refund!)

      result = described_class.refund_payment(payment)

      expect(result).to be false
    end
  end

  describe '.user_stats' do
    let(:payments_relation) { double('ActiveRecord::Relation') }
    let(:succeeded_payments) { double('ActiveRecord::Relation') }

    before do
      allow(payer).to receive(:payments).and_return(payments_relation)
      allow(payments_relation).to receive(:where).and_return(payments_relation)
      allow(payments_relation).to receive(:succeeded).and_return(succeeded_payments)
      allow(succeeded_payments).to receive(:sum).with(:amount_cents).and_return(5000)
      allow(succeeded_payments).to receive(:count).and_return(10)
      allow(succeeded_payments).to receive(:group).with(:payment_type).and_return(succeeded_payments)
    end

    it 'filters payments by period' do
      expect(payments_relation).to receive(:where) do |condition|
        expect(condition).to match(/created_at >/)
        payments_relation
      end

      described_class.user_stats(payer, period: 30.days)
    end

    it 'returns total spent' do
      result = described_class.user_stats(payer)

      expect(result[:total_spent]).to eq(5000)
    end

    it 'returns total count' do
      result = described_class.user_stats(payer)

      expect(result[:total_count]).to eq(10)
    end

    it 'returns breakdown by payment type' do
      allow(succeeded_payments).to receive(:sum).with(:amount_cents).and_return({ 'donation' => 3000, 'tip' => 2000 })

      result = described_class.user_stats(payer)

      expect(result[:by_type]).to eq({ 'donation' => 3000, 'tip' => 2000 })
    end

    it 'defaults to 30 days period' do
      expect(payments_relation).to receive(:where).with(/created_at >/)

      described_class.user_stats(payer)
    end
  end

  describe '.streamer_earnings' do
    let(:earnings_relation) { double('ActiveRecord::Relation') }
    let(:succeeded_earnings) { double('ActiveRecord::Relation') }

    before do
      allow(recipient).to receive(:received_payments).and_return(earnings_relation)
      allow(earnings_relation).to receive(:where).and_return(earnings_relation)
      allow(earnings_relation).to receive(:succeeded).and_return(succeeded_earnings)
      allow(succeeded_earnings).to receive(:sum).with(:recipient_amount_cents).and_return(9500)
      allow(succeeded_earnings).to receive(:sum).with(:platform_fee_cents).and_return(500)
      allow(succeeded_earnings).to receive(:count).and_return(10)
      allow(succeeded_earnings).to receive(:group).with(:payment_type).and_return(succeeded_earnings)
    end

    it 'filters earnings by period' do
      expect(earnings_relation).to receive(:where) do |condition|
        expect(condition).to match(/created_at >/)
        earnings_relation
      end

      described_class.streamer_earnings(recipient, period: 30.days)
    end

    it 'returns total earned (recipient amount)' do
      result = described_class.streamer_earnings(recipient)

      expect(result[:total_earned]).to eq(9500)
    end

    it 'returns total count' do
      result = described_class.streamer_earnings(recipient)

      expect(result[:total_count]).to eq(10)
    end

    it 'returns breakdown by payment type' do
      allow(succeeded_earnings).to receive(:sum).with(:recipient_amount_cents)
        .and_return({ 'donation' => 5700, 'tip' => 3800 })

      result = described_class.streamer_earnings(recipient)

      expect(result[:by_type]).to eq({ 'donation' => 5700, 'tip' => 3800 })
    end

    it 'returns platform fees' do
      result = described_class.streamer_earnings(recipient)

      expect(result[:platform_fees]).to eq(500)
    end

    it 'defaults to 30 days period' do
      expect(earnings_relation).to receive(:where).with(/created_at >/)

      described_class.streamer_earnings(recipient)
    end
  end
end
