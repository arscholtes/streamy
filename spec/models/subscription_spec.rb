require 'rails_helper'

RSpec.describe Subscription, type: :model do
  let(:user) { create(:user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:stripe_subscription_id) }
    it { should validate_presence_of(:stripe_customer_id) }
    it { should validate_presence_of(:plan) }
    it { should validate_inclusion_of(:plan).in_array(['free', 'pro', 'enterprise']) }
  end

  describe 'scopes' do
    let!(:active_subscription) { create(:subscription, user: user, status: 'active') }
    let!(:canceled_subscription) { create(:subscription, user: create(:user), status: 'canceled') }
    let!(:trialing_subscription) { create(:subscription, user: create(:user), status: 'trialing') }

    describe '.active' do
      it 'returns only active subscriptions' do
        expect(Subscription.active).to include(active_subscription)
        expect(Subscription.active).not_to include(canceled_subscription)
      end
    end

    describe '.canceled' do
      it 'returns only canceled subscriptions' do
        expect(Subscription.canceled).to include(canceled_subscription)
        expect(Subscription.canceled).not_to include(active_subscription)
      end
    end

    describe '.trialing' do
      it 'returns only trialing subscriptions' do
        expect(Subscription.trialing).to include(trialing_subscription)
        expect(Subscription.trialing).not_to include(active_subscription)
      end
    end
  end

  describe '#active?' do
    it 'returns true for active status' do
      subscription = build(:subscription, status: 'active')
      expect(subscription.active?).to be true
    end

    it 'returns true for trialing status' do
      subscription = build(:subscription, status: 'trialing')
      expect(subscription.active?).to be true
    end

    it 'returns false for canceled status' do
      subscription = build(:subscription, status: 'canceled')
      expect(subscription.active?).to be false
    end
  end

  describe '#plan_price' do
    it 'returns correct price for pro plan' do
      subscription = build(:subscription, plan: 'pro')
      expect(subscription.plan_price).to eq(1900)
    end

    it 'returns correct price for enterprise plan' do
      subscription = build(:subscription, plan: 'enterprise')
      expect(subscription.plan_price).to eq(9900)
    end

    it 'returns 0 for free plan' do
      subscription = build(:subscription, plan: 'free')
      expect(subscription.plan_price).to eq(0)
    end
  end

  describe '#cancel!' do
    let(:subscription) { create(:subscription, user: user, status: 'active') }

    it 'marks subscription for cancellation at period end' do
      allow(Stripe::Subscription).to receive(:update).and_return(
        double(cancel_at_period_end: true)
      )

      expect { subscription.cancel! }.to change { subscription.cancel_at_period_end }.to(true)
    end

    it 'sets canceled_at timestamp' do
      allow(Stripe::Subscription).to receive(:update).and_return(
        double(cancel_at_period_end: true)
      )

      expect { subscription.cancel! }.to change { subscription.canceled_at }.from(nil)
    end
  end

  describe '#reactivate!' do
    let(:subscription) do
      create(:subscription, user: user, status: 'active', cancel_at_period_end: true)
    end

    it 'removes cancellation' do
      allow(Stripe::Subscription).to receive(:update).and_return(
        double(cancel_at_period_end: false)
      )

      expect { subscription.reactivate! }.to change { subscription.cancel_at_period_end }.to(false)
    end
  end

  describe 'callbacks' do
    describe 'after_save :sync_user_tier' do
      it 'updates user subscription_tier when status becomes active' do
        subscription = create(:subscription, user: user, plan: 'pro', status: 'incomplete')

        expect {
          subscription.update!(status: 'active')
        }.to change { user.reload.subscription_tier }.from('free').to('pro')
      end

      it 'sets user tier to free when subscription is canceled' do
        user.update!(subscription_tier: 'pro')
        subscription = create(:subscription, user: user, plan: 'pro', status: 'active')

        expect {
          subscription.update!(status: 'canceled')
        }.to change { user.reload.subscription_tier }.from('pro').to('free')
      end
    end
  end
end
