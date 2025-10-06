require 'rails_helper'

RSpec.describe SubscriptionsController, type: :request do
  let(:user) { create(:user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
  end

  describe 'GET /subscriptions/new' do
    it 'redirects to billing settings' do
      get new_subscription_path

      expect(response).to redirect_to(settings_path(tab: 'billing'))
    end
  end

  describe 'POST /subscriptions' do
    let(:service) { instance_double(SubscriptionService) }
    let(:session_double) { double('Stripe::Checkout::Session', url: 'https://checkout.stripe.com/session123') }

    before do
      allow(SubscriptionService).to receive(:new).with(user).and_return(service)
    end

    it 'creates checkout session for pro plan' do
      allow(service).to receive(:create_checkout_session).and_return(session_double)

      post subscriptions_path, params: { plan: 'pro' }

      expect(response).to redirect_to('https://checkout.stripe.com/session123')
    end

    it 'creates checkout session for enterprise plan' do
      allow(service).to receive(:create_checkout_session).and_return(session_double)

      post subscriptions_path, params: { plan: 'enterprise' }

      expect(response).to redirect_to('https://checkout.stripe.com/session123')
    end

    it 'rejects free plan' do
      post subscriptions_path, params: { plan: 'free' }

      expect(response).to redirect_to(settings_path(tab: 'billing'))
      expect(flash[:error]).to eq('Invalid subscription plan')
    end

    it 'rejects invalid plan' do
      post subscriptions_path, params: { plan: 'invalid' }

      expect(response).to redirect_to(settings_path(tab: 'billing'))
      expect(flash[:error]).to eq('Invalid subscription plan')
    end

    it 'rejects when user already has active subscription' do
      create(:subscription, user: user, status: 'active')

      post subscriptions_path, params: { plan: 'pro' }

      expect(response).to redirect_to(settings_path(tab: 'billing'))
      expect(flash[:error]).to eq('You already have an active subscription')
    end

    it 'handles Stripe errors gracefully' do
      allow(service).to receive(:create_checkout_session).and_raise(Stripe::StripeError.new('API error'))

      post subscriptions_path, params: { plan: 'pro' }

      expect(response).to redirect_to(settings_path(tab: 'billing'))
      expect(flash[:error]).to eq('Failed to create checkout session. Please try again.')
    end

    it 'requires login' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false)

      post subscriptions_path, params: { plan: 'pro' }

      expect(response).to redirect_to(login_path)
    end
  end

  describe 'GET /subscription' do
    it 'shows active subscription' do
      subscription = create(:subscription, user: user, status: 'active')

      get subscription_path

      expect(response).to have_http_status(:success)
      expect(assigns(:subscription)).to eq(subscription)
    end

    it 'shows last subscription if none active' do
      old_sub = create(:subscription, user: user, status: 'canceled', created_at: 2.days.ago)
      newer_sub = create(:subscription, user: user, status: 'canceled', created_at: 1.day.ago)

      get subscription_path

      expect(response).to have_http_status(:success)
      expect(assigns(:subscription)).to eq(newer_sub)
    end

    it 'redirects when user has no subscriptions' do
      get subscription_path

      expect(response).to redirect_to(settings_path(tab: 'billing'))
      expect(flash[:notice]).to eq("You don't have any subscriptions yet")
    end

    it 'loads recent payments' do
      subscription = create(:subscription, user: user, status: 'active')
      payment = create(:payment, user: user, payment_type: 'subscription')

      allow(user).to receive(:payments).and_return(Payment.where(user: user))

      get subscription_path

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /subscriptions/success' do
    it 'shows success message' do
      get success_subscription_path

      expect(response).to redirect_to(subscription_path)
      expect(flash[:success]).to eq('Successfully subscribed! Thank you for your support.')
    end
  end

  describe 'DELETE /subscription/cancel' do
    let(:service) { instance_double(SubscriptionService) }

    before do
      allow(SubscriptionService).to receive(:new).with(user).and_return(service)
    end

    it 'cancels subscription successfully' do
      allow(service).to receive(:cancel_subscription).and_return(true)

      delete cancel_subscription_path

      expect(response).to redirect_to(subscription_path)
      expect(flash[:success]).to eq('Your subscription will be canceled at the end of the current billing period')
    end

    it 'handles cancellation failure' do
      allow(service).to receive(:cancel_subscription).and_return(false)

      delete cancel_subscription_path

      expect(response).to redirect_to(subscription_path)
      expect(flash[:error]).to eq('Failed to cancel subscription')
    end
  end

  describe 'POST /subscription/reactivate' do
    let(:service) { instance_double(SubscriptionService) }

    before do
      allow(SubscriptionService).to receive(:new).with(user).and_return(service)
    end

    it 'reactivates subscription successfully' do
      allow(service).to receive(:reactivate_subscription).and_return(true)

      post reactivate_subscription_path

      expect(response).to redirect_to(subscription_path)
      expect(flash[:success]).to eq('Your subscription has been reactivated')
    end

    it 'handles reactivation failure' do
      allow(service).to receive(:reactivate_subscription).and_return(false)

      post reactivate_subscription_path

      expect(response).to redirect_to(subscription_path)
      expect(flash[:error]).to eq('Failed to reactivate subscription')
    end
  end

  describe 'POST /subscription/change_plan' do
    let(:service) { instance_double(SubscriptionService) }

    before do
      allow(SubscriptionService).to receive(:new).with(user).and_return(service)
    end

    it 'changes plan successfully' do
      allow(service).to receive(:change_plan).with('enterprise').and_return(true)

      post change_plan_subscription_path, params: { plan: 'enterprise' }

      expect(response).to redirect_to(subscription_path)
      expect(flash[:success]).to eq('Your plan has been changed to Enterprise')
    end

    it 'rejects free plan' do
      post change_plan_subscription_path, params: { plan: 'free' }

      expect(response).to redirect_to(subscription_path)
      expect(flash[:error]).to eq('Invalid plan')
    end

    it 'rejects invalid plan' do
      post change_plan_subscription_path, params: { plan: 'invalid' }

      expect(response).to redirect_to(subscription_path)
      expect(flash[:error]).to eq('Invalid plan')
    end

    it 'handles change plan failure' do
      allow(service).to receive(:change_plan).with('pro').and_return(false)

      post change_plan_subscription_path, params: { plan: 'pro' }

      expect(response).to redirect_to(subscription_path)
      expect(flash[:error]).to eq('Failed to change plan')
    end
  end

  describe 'GET /subscription/portal' do
    let(:service) { instance_double(SubscriptionService) }
    let(:portal_session) { double('Stripe::BillingPortal::Session', url: 'https://billing.stripe.com/session123') }

    before do
      allow(SubscriptionService).to receive(:new).with(user).and_return(service)
    end

    it 'redirects to Stripe billing portal' do
      allow(service).to receive(:create_portal_session).and_return(portal_session)

      get portal_subscription_path

      expect(response).to redirect_to('https://billing.stripe.com/session123')
    end

    it 'handles portal creation failure' do
      allow(service).to receive(:create_portal_session).and_return(nil)

      get portal_subscription_path

      expect(response).to redirect_to(subscription_path)
      expect(flash[:error]).to eq('Failed to create portal session')
    end
  end
end
