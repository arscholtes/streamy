require 'rails_helper'

RSpec.describe Payment, type: :model do
  let(:user) { create(:user) }
  let(:recipient) { create(:user) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:recipient).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:amount_cents) }
    it { should validate_presence_of(:payment_type) }
    it { should validate_inclusion_of(:payment_type).in_array(%w[subscription donation tip channel_subscription refund]) }
  end

  describe 'scopes' do
    let!(:succeeded_payment) { create(:payment, user: user, status: 'succeeded') }
    let!(:pending_payment) { create(:payment, user: user, status: 'pending') }
    let!(:failed_payment) { create(:payment, user: user, status: 'failed') }
    let!(:donation) { create(:payment, user: user, payment_type: 'donation') }
    let!(:subscription_payment) { create(:payment, user: user, payment_type: 'subscription') }

    describe '.succeeded' do
      it 'returns only succeeded payments' do
        expect(Payment.succeeded).to include(succeeded_payment)
        expect(Payment.succeeded).not_to include(pending_payment, failed_payment)
      end
    end

    describe '.pending' do
      it 'returns only pending payments' do
        expect(Payment.pending).to include(pending_payment)
        expect(Payment.pending).not_to include(succeeded_payment, failed_payment)
      end
    end

    describe '.failed' do
      it 'returns only failed payments' do
        expect(Payment.failed).to include(failed_payment)
        expect(Payment.failed).not_to include(succeeded_payment, pending_payment)
      end
    end

    describe '.donations' do
      it 'returns only donations' do
        expect(Payment.donations).to include(donation)
        expect(Payment.donations).not_to include(subscription_payment)
      end
    end

    describe '.subscriptions' do
      it 'returns only subscription payments' do
        expect(Payment.subscriptions).to include(subscription_payment)
        expect(Payment.subscriptions).not_to include(donation)
      end
    end

    describe '.recent' do
      it 'orders payments by created_at desc' do
        payments = Payment.recent.to_a
        expect(payments.first.created_at).to be >= payments.last.created_at
      end
    end
  end

  describe 'status methods' do
    describe '#succeeded?' do
      it 'returns true for succeeded status' do
        payment = build(:payment, status: 'succeeded')
        expect(payment.succeeded?).to be true
      end

      it 'returns false for other statuses' do
        payment = build(:payment, status: 'pending')
        expect(payment.succeeded?).to be false
      end
    end

    describe '#failed?' do
      it 'returns true for failed status' do
        payment = build(:payment, status: 'failed')
        expect(payment.failed?).to be true
      end

      it 'returns false for other statuses' do
        payment = build(:payment, status: 'succeeded')
        expect(payment.failed?).to be false
      end
    end

    describe '#pending?' do
      it 'returns true for pending status' do
        payment = build(:payment, status: 'pending')
        expect(payment.pending?).to be true
      end

      it 'returns false for other statuses' do
        payment = build(:payment, status: 'succeeded')
        expect(payment.pending?).to be false
      end
    end
  end

  describe '.calculate_platform_fee' do
    it 'calculates 5% platform fee by default' do
      fee = Payment.calculate_platform_fee(10000)
      expect(fee).to eq(500)
    end

    it 'calculates custom platform fee percentage' do
      fee = Payment.calculate_platform_fee(10000, 10.0)
      expect(fee).to eq(1000)
    end

    it 'rounds down to integer cents' do
      fee = Payment.calculate_platform_fee(1000, 3.33)
      expect(fee).to eq(33)
    end
  end

  describe '.calculate_recipient_amount' do
    it 'subtracts platform fee from total' do
      amount = Payment.calculate_recipient_amount(10000, 500)
      expect(amount).to eq(9500)
    end
  end

  describe '#refund!' do
    let(:payment) do
      create(:payment,
        user: user,
        status: 'succeeded',
        amount_cents: 10000,
        stripe_charge_id: 'ch_123456'
      )
    end

    it 'creates refund in Stripe and updates payment' do
      refund_double = double(id: 'ref_123', amount: 10000)
      allow(Stripe::Refund).to receive(:create).with({
        charge: 'ch_123456',
        amount: 10000
      }).and_return(refund_double)

      expect {
        payment.refund!
      }.to change { payment.status }.to('refunded')
    end

    it 'supports partial refunds' do
      refund_double = double(id: 'ref_123', amount: 5000)
      allow(Stripe::Refund).to receive(:create).with({
        charge: 'ch_123456',
        amount: 5000
      }).and_return(refund_double)

      payment.refund!(amount_cents: 5000)
      expect(payment.refund_amount_cents).to eq(5000)
    end
  end

  describe '#amount' do
    it 'returns amount in dollars' do
      payment = build(:payment, amount_cents: 1250)
      expect(payment.amount).to eq(12.50)
    end
  end

  describe '#platform_fee' do
    it 'returns platform fee in dollars' do
      payment = build(:payment, platform_fee_cents: 500)
      expect(payment.platform_fee).to eq(5.00)
    end
  end

  describe '#recipient_amount' do
    it 'returns recipient amount in dollars' do
      payment = build(:payment, recipient_amount_cents: 9500)
      expect(payment.recipient_amount).to eq(95.00)
    end
  end
end
