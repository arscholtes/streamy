require 'rails_helper'

RSpec.describe SubscriptionService, type: :service do
  let(:user) { double('User', id: 1, email: 'test@example.com', stripe_customer_id: nil, update!: true, subscriptions: double(any?: false, last: nil)) }
  let(:service) { described_class.new(user) }

  before do
    # Mock Subscription::PLANS
    stub_const('Subscription::PLANS', {
      'free' => { name: 'Free', price: 0 },
      'pro' => { name: 'Pro', price: 999, stripe_price_id: 'price_pro123' },
      'enterprise' => { name: 'Enterprise', price: 2999, stripe_price_id: 'price_ent456' }
    })
  end

  describe '#initialize' do
    it 'sets the user' do
      expect(service.user).to eq(user)
    end
  end

  describe '#create_checkout_session' do
    let(:stripe_customer) { double('Stripe::Customer', id: 'cus_123') }
    let(:checkout_session) { double('Stripe::Checkout::Session', id: 'cs_123', url: 'https://checkout.stripe.com/123') }

    before do
      allow(service).to receive(:get_or_create_customer).and_return('cus_123')
      allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)
    end

    it 'creates checkout session for pro plan' do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        customer: 'cus_123',
        mode: 'subscription',
        line_items: [{ price: 'price_pro123', quantity: 1 }]
      ))

      service.create_checkout_session(
        plan: 'pro',
        success_url: 'https://myapp.com/success',
        cancel_url: 'https://myapp.com/cancel'
      )
    end

    it 'includes success and cancel URLs' do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        success_url: 'https://myapp.com/success',
        cancel_url: 'https://myapp.com/cancel'
      ))

      service.create_checkout_session(
        plan: 'pro',
        success_url: 'https://myapp.com/success',
        cancel_url: 'https://myapp.com/cancel'
      )
    end

    it 'allows promotion codes' do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        allow_promotion_codes: true
      ))

      service.create_checkout_session(
        plan: 'pro',
        success_url: 'https://myapp.com/success',
        cancel_url: 'https://myapp.com/cancel'
      )
    end

    it 'includes metadata with user_id and plan' do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        metadata: hash_including(user_id: 1, plan: 'pro'),
        subscription_data: hash_including(metadata: hash_including(user_id: 1, plan: 'pro'))
      ))

      service.create_checkout_session(
        plan: 'pro',
        success_url: 'https://myapp.com/success',
        cancel_url: 'https://myapp.com/cancel'
      )
    end

    it 'raises error for invalid plan' do
      expect {
        service.create_checkout_session(
          plan: 'invalid',
          success_url: 'https://myapp.com/success',
          cancel_url: 'https://myapp.com/cancel'
        )
      }.to raise_error(ArgumentError, /Invalid plan/)
    end

    it 'raises error for free plan' do
      expect {
        service.create_checkout_session(
          plan: 'free',
          success_url: 'https://myapp.com/success',
          cancel_url: 'https://myapp.com/cancel'
        )
      }.to raise_error(ArgumentError, /must be pro or enterprise/)
    end

    it 'raises error if price_id not configured' do
      stub_const('Subscription::PLANS', {
        'pro' => { name: 'Pro', price: 999 }
      })

      expect {
        service.create_checkout_session(
          plan: 'pro',
          success_url: 'https://myapp.com/success',
          cancel_url: 'https://myapp.com/cancel'
        )
      }.to raise_error(ArgumentError, /Stripe price ID not configured/)
    end

    it 'logs and raises Stripe errors' do
      allow(Stripe::Checkout::Session).to receive(:create).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Stripe checkout error/)

      expect {
        service.create_checkout_session(
          plan: 'pro',
          success_url: 'https://myapp.com/success',
          cancel_url: 'https://myapp.com/cancel'
        )
      }.to raise_error(Stripe::StripeError)
    end

    it 'handles callable price_id' do
      stub_const('Subscription::PLANS', {
        'pro' => { name: 'Pro', price: 999, stripe_price_id: -> { 'price_dynamic' } }
      })

      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        line_items: [{ price: 'price_dynamic', quantity: 1 }]
      ))

      service.create_checkout_session(
        plan: 'pro',
        success_url: 'https://myapp.com/success',
        cancel_url: 'https://myapp.com/cancel'
      )
    end
  end

  describe '#create_subscription_from_stripe' do
    let(:stripe_subscription) do
      double('Stripe::Subscription',
        id: 'sub_123',
        customer: 'cus_123',
        status: 'active',
        current_period_start: 1234567890,
        current_period_end: 1234577890,
        cancel_at_period_end: false,
        trial_start: nil,
        trial_end: nil,
        metadata: { 'plan' => 'pro' }
      )
    end

    let(:subscription_model) { double('Subscription') }

    before do
      allow(Subscription).to receive(:create!).and_return(subscription_model)
    end

    it 'creates subscription record from Stripe subscription' do
      expect(Subscription).to receive(:create!).with(hash_including(
        user: user,
        stripe_subscription_id: 'sub_123',
        stripe_customer_id: 'cus_123',
        status: 'active',
        plan: 'pro',
        cancel_at_period_end: false
      ))

      service.create_subscription_from_stripe(stripe_subscription)
    end

    it 'converts timestamps to Time objects' do
      expect(Subscription).to receive(:create!) do |args|
        expect(args[:current_period_start]).to be_a(Time)
        expect(args[:current_period_end]).to be_a(Time)
      end

      service.create_subscription_from_stripe(stripe_subscription)
    end

    it 'includes trial dates if present' do
      allow(stripe_subscription).to receive(:trial_start).and_return(1234567800)
      allow(stripe_subscription).to receive(:trial_end).and_return(1234567850)

      expect(Subscription).to receive(:create!) do |args|
        expect(args[:trial_start]).to be_a(Time)
        expect(args[:trial_end]).to be_a(Time)
      end

      service.create_subscription_from_stripe(stripe_subscription)
    end
  end

  describe '#update_subscription_from_stripe' do
    let(:subscription) { double('Subscription', update!: true) }
    let(:stripe_subscription) do
      double('Stripe::Subscription',
        id: 'sub_123',
        status: 'active',
        current_period_start: 1234567890,
        current_period_end: 1234577890,
        cancel_at_period_end: false,
        canceled_at: nil
      )
    end

    before do
      allow(Subscription).to receive(:find_by).and_return(subscription)
    end

    it 'finds subscription by stripe_subscription_id' do
      expect(Subscription).to receive(:find_by).with(stripe_subscription_id: 'sub_123')

      service.update_subscription_from_stripe(stripe_subscription)
    end

    it 'updates subscription with Stripe data' do
      expect(subscription).to receive(:update!).with(hash_including(
        status: 'active',
        cancel_at_period_end: false
      ))

      service.update_subscription_from_stripe(stripe_subscription)
    end

    it 'returns nil if subscription not found' do
      allow(Subscription).to receive(:find_by).and_return(nil)

      result = service.update_subscription_from_stripe(stripe_subscription)

      expect(result).to be_nil
    end

    it 'includes canceled_at if present' do
      allow(stripe_subscription).to receive(:canceled_at).and_return(1234567900)

      expect(subscription).to receive(:update!) do |args|
        expect(args[:canceled_at]).to be_a(Time)
      end

      service.update_subscription_from_stripe(stripe_subscription)
    end
  end

  describe '#cancel_subscription' do
    let(:subscription) { double('Subscription', cancel!: true) }

    before do
      allow(user).to receive(:active_subscription).and_return(subscription)
    end

    it 'cancels active subscription' do
      expect(subscription).to receive(:cancel!)

      service.cancel_subscription
    end

    it 'returns false if no active subscription' do
      allow(user).to receive(:active_subscription).and_return(nil)

      expect(service.cancel_subscription).to be false
    end
  end

  describe '#reactivate_subscription' do
    let(:subscription) { double('Subscription', reactivate!: true) }
    let(:subscriptions_relation) { double('ActiveRecord::Relation') }

    before do
      allow(user).to receive(:subscriptions).and_return(subscriptions_relation)
      allow(subscriptions_relation).to receive(:where).and_return(subscriptions_relation)
      allow(subscriptions_relation).to receive(:first).and_return(subscription)
    end

    it 'reactivates canceled subscription' do
      expect(subscription).to receive(:reactivate!)

      service.reactivate_subscription
    end

    it 'finds subscription with cancel_at_period_end true' do
      expect(subscriptions_relation).to receive(:where).with(cancel_at_period_end: true)

      service.reactivate_subscription
    end

    it 'returns false if no canceled subscription' do
      allow(subscriptions_relation).to receive(:first).and_return(nil)

      expect(service.reactivate_subscription).to be false
    end
  end

  describe '#change_plan' do
    let(:subscription) { double('Subscription', stripe_subscription_id: 'sub_123', update!: true) }
    let(:stripe_subscription) do
      double('Stripe::Subscription',
        id: 'sub_123',
        items: double(data: [double(id: 'si_123')])
      )
    end

    before do
      allow(user).to receive(:active_subscription).and_return(subscription)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(stripe_subscription)
      allow(Stripe::Subscription).to receive(:update).and_return(stripe_subscription)
    end

    it 'retrieves existing subscription from Stripe' do
      expect(Stripe::Subscription).to receive(:retrieve).with('sub_123')

      service.change_plan('enterprise')
    end

    it 'updates subscription with new price' do
      expect(Stripe::Subscription).to receive(:update).with(
        'sub_123',
        hash_including(
          items: [{ id: 'si_123', price: 'price_ent456' }],
          proration_behavior: 'always_invoice',
          metadata: { plan: 'enterprise' }
        )
      )

      service.change_plan('enterprise')
    end

    it 'updates local subscription record' do
      expect(subscription).to receive(:update!).with(plan: 'enterprise')

      service.change_plan('enterprise')
    end

    it 'returns true on success' do
      expect(service.change_plan('enterprise')).to be true
    end

    it 'returns false if no active subscription' do
      allow(user).to receive(:active_subscription).and_return(nil)

      expect(service.change_plan('pro')).to be false
    end

    it 'raises error for invalid plan' do
      expect {
        service.change_plan('invalid')
      }.to raise_error(ArgumentError, /Invalid plan/)
    end

    it 'returns false and logs error on Stripe error' do
      allow(Stripe::Subscription).to receive(:retrieve).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to change subscription plan/)

      expect(service.change_plan('enterprise')).to be false
    end
  end

  describe '#create_portal_session' do
    let(:subscription) { double('Subscription', stripe_customer_id: 'cus_123') }
    let(:portal_session) { double('Stripe::BillingPortal::Session', url: 'https://billing.stripe.com/session/123') }

    before do
      allow(user).to receive(:active_subscription).and_return(subscription)
      allow(Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)
    end

    it 'creates billing portal session' do
      expect(Stripe::BillingPortal::Session).to receive(:create).with(hash_including(
        customer: 'cus_123',
        return_url: 'https://myapp.com/account'
      ))

      service.create_portal_session(return_url: 'https://myapp.com/account')
    end

    it 'returns portal session' do
      result = service.create_portal_session(return_url: 'https://myapp.com/account')

      expect(result).to eq(portal_session)
    end

    it 'uses last subscription if no active subscription' do
      allow(user).to receive(:active_subscription).and_return(nil)
      allow(user.subscriptions).to receive(:last).and_return(subscription)

      expect(Stripe::BillingPortal::Session).to receive(:create)

      service.create_portal_session(return_url: 'https://myapp.com/account')
    end

    it 'returns nil if no subscription' do
      allow(user).to receive(:active_subscription).and_return(nil)
      allow(user.subscriptions).to receive(:last).and_return(nil)

      result = service.create_portal_session(return_url: 'https://myapp.com/account')

      expect(result).to be_nil
    end

    it 'returns nil and logs error on Stripe error' do
      allow(Stripe::BillingPortal::Session).to receive(:create).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to create portal session/)

      expect(service.create_portal_session(return_url: 'url')).to be_nil
    end
  end

  describe '#get_or_create_customer' do
    it 'returns existing customer ID from user' do
      allow(user).to receive(:stripe_customer_id).and_return('cus_existing')

      result = service.send(:get_or_create_customer)

      expect(result).to eq('cus_existing')
    end

    it 'returns customer ID from last subscription if user has no customer_id' do
      allow(user).to receive(:stripe_customer_id).and_return(nil)
      allow(user.subscriptions).to receive(:any?).and_return(true)
      last_sub = double('Subscription', stripe_customer_id: 'cus_from_sub')
      allow(user.subscriptions).to receive(:last).and_return(last_sub)

      expect(user).to receive(:update!).with(stripe_customer_id: 'cus_from_sub')

      result = service.send(:get_or_create_customer)

      expect(result).to eq('cus_from_sub')
    end

    it 'creates new Stripe customer if none exists' do
      allow(user).to receive(:stripe_customer_id).and_return(nil)
      allow(user).to receive(:username).and_return('testuser')
      allow(user.subscriptions).to receive(:any?).and_return(false)

      stripe_customer = double('Stripe::Customer', id: 'cus_new123')
      allow(Stripe::Customer).to receive(:create).and_return(stripe_customer)

      expect(Stripe::Customer).to receive(:create).with(hash_including(
        email: 'test@example.com',
        name: 'testuser',
        metadata: { user_id: 1 }
      ))

      expect(user).to receive(:update!).with(stripe_customer_id: 'cus_new123')

      result = service.send(:get_or_create_customer)

      expect(result).to eq('cus_new123')
    end
  end
end
