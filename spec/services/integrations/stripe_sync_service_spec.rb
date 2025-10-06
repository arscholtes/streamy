require 'rails_helper'

RSpec.describe Integrations::StripeSyncService, type: :service do
  let(:stripe_account) do
    double('StripeAccount',
      id: 1,
      stripe_id: 'acct_123',
      update!: true
    )
  end
  let(:service) { described_class.new(stripe_account) }

  describe '#initialize' do
    it 'sets the stripe account' do
      expect(service.stripe_account).to eq(stripe_account)
    end
  end

  describe '#sync' do
    let(:stripe_account_obj) do
      double('Stripe::Account',
        email: 'stripe@example.com',
        type: 'express',
        charges_enabled: true,
        payouts_enabled: true
      )
    end

    before do
      allow(Stripe::Account).to receive(:retrieve).and_return(stripe_account_obj)
    end

    it 'retrieves account from Stripe' do
      expect(Stripe::Account).to receive(:retrieve).with('acct_123')

      service.sync
    end

    it 'updates local stripe account record' do
      expect(stripe_account).to receive(:update!).with(hash_including(
        email: 'stripe@example.com',
        account_type: 'express',
        charges_enabled: true,
        payouts_enabled: true
      ))

      service.sync
    end

    it 'updates last_synced_at timestamp' do
      expect(stripe_account).to receive(:update!).with(hash_including(:last_synced_at))

      service.sync
    end

    it 'returns true on success' do
      expect(service.sync).to be true
    end

    it 'returns false and logs error on Stripe error' do
      allow(Stripe::Account).to receive(:retrieve).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to sync Stripe account/)

      expect(service.sync).to be false
    end
  end

  describe '#balance' do
    let(:balance_obj) do
      double('Stripe::Balance',
        available: [
          double(amount: 10000, currency: 'usd'),
          double(amount: 5000, currency: 'eur')
        ],
        pending: [
          double(amount: 2000, currency: 'usd')
        ]
      )
    end

    before do
      allow(Stripe::Balance).to receive(:retrieve).and_return(balance_obj)
    end

    it 'retrieves balance for connected account' do
      expect(Stripe::Balance).to receive(:retrieve).with(hash_including(
        stripe_account: 'acct_123'
      ))

      service.balance
    end

    it 'returns formatted balance data' do
      result = service.balance

      expect(result[:available]).to be_an(Array)
      expect(result[:available].first[:amount]).to eq(10000)
      expect(result[:available].first[:currency]).to eq('usd')
      expect(result[:pending]).to be_an(Array)
      expect(result[:pending].first[:amount]).to eq(2000)
    end

    it 'returns nil and logs error on Stripe error' do
      allow(Stripe::Balance).to receive(:retrieve).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to get balance/)

      expect(service.balance).to be_nil
    end
  end

  describe '#recent_payouts' do
    let(:payouts_list) do
      double('Stripe::ListObject',
        data: [
          double('Payout',
            id: 'po_123',
            amount: 10000,
            currency: 'usd',
            status: 'paid',
            arrival_date: 1234567890,
            created: 1234567800
          )
        ]
      )
    end

    before do
      allow(Stripe::Payout).to receive(:list).and_return(payouts_list)
    end

    it 'retrieves recent payouts' do
      expect(Stripe::Payout).to receive(:list).with(
        { limit: 10 },
        { stripe_account: 'acct_123' }
      )

      service.recent_payouts
    end

    it 'accepts custom limit' do
      expect(Stripe::Payout).to receive(:list).with(
        { limit: 20 },
        { stripe_account: 'acct_123' }
      )

      service.recent_payouts(limit: 20)
    end

    it 'returns formatted payout data' do
      result = service.recent_payouts

      expect(result).to be_an(Array)
      expect(result.first[:id]).to eq('po_123')
      expect(result.first[:amount]).to eq(10000)
      expect(result.first[:currency]).to eq('usd')
      expect(result.first[:status]).to eq('paid')
      expect(result.first[:arrival_date]).to be_a(Time)
    end

    it 'returns empty array and logs error on Stripe error' do
      allow(Stripe::Payout).to receive(:list).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to get payouts/)

      expect(service.recent_payouts).to eq([])
    end
  end

  describe '#requires_action?' do
    let(:stripe_account_obj) do
      double('Stripe::Account',
        requirements: double(
          currently_due: [],
          eventually_due: []
        )
      )
    end

    before do
      allow(stripe_account).to receive(:charges_enabled).and_return(true)
      allow(stripe_account).to receive(:payouts_enabled).and_return(true)
      allow(Stripe::Account).to receive(:retrieve).and_return(stripe_account_obj)
    end

    it 'returns true if charges not enabled' do
      allow(stripe_account).to receive(:charges_enabled).and_return(false)

      expect(service.requires_action?).to be true
    end

    it 'returns true if payouts not enabled' do
      allow(stripe_account).to receive(:payouts_enabled).and_return(false)

      expect(service.requires_action?).to be true
    end

    it 'returns true if requirements currently due' do
      allow(stripe_account_obj.requirements).to receive(:currently_due).and_return(['document'])

      expect(service.requires_action?).to be true
    end

    it 'returns true if requirements eventually due' do
      allow(stripe_account_obj.requirements).to receive(:eventually_due).and_return(['document'])

      expect(service.requires_action?).to be true
    end

    it 'returns false when account is fully set up' do
      expect(service.requires_action?).to be false
    end

    it 'returns false and logs error on Stripe error' do
      allow(Stripe::Account).to receive(:retrieve).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to check account requirements/)

      expect(service.requires_action?).to be false
    end
  end
end
