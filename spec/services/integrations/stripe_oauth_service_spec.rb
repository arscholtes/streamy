require 'rails_helper'

RSpec.describe Integrations::StripeOauthService, type: :service do
  let(:user) { double('User', id: 1, email: 'test@example.com', stripe_account: nil, build_stripe_account: stripe_account) }
  let(:stripe_account) { double('StripeAccount', update!: true) }
  let(:service) { described_class.new(user) }

  before do
    # Mock Rails.configuration.stripe
    allow(Rails.configuration).to receive(:stripe).and_return(
      { connect_client_id: 'ca_test123' }
    )
  end

  describe '#initialize' do
    it 'sets the user' do
      expect(service.user).to eq(user)
    end
  end

  describe '#authorization_url' do
    let(:redirect_uri) { 'https://myapp.com/stripe/callback' }

    it 'generates Stripe Connect authorization URL' do
      url = service.authorization_url(redirect_uri: redirect_uri)

      expect(url).to start_with('https://connect.stripe.com/express/oauth/authorize')
    end

    it 'includes client_id parameter' do
      url = service.authorization_url(redirect_uri: redirect_uri)
      params = CGI.parse(URI.parse(url).query)

      expect(params['client_id']).to eq(['ca_test123'])
    end

    it 'includes redirect_uri parameter' do
      url = service.authorization_url(redirect_uri: redirect_uri)
      params = CGI.parse(URI.parse(url).query)

      expect(params['redirect_uri']).to eq([redirect_uri])
    end

    it 'includes state parameter' do
      url = service.authorization_url(redirect_uri: redirect_uri)
      params = CGI.parse(URI.parse(url).query)

      expect(params['state'].first).not_to be_nil
      expect(params['state'].first.length).to be > 20
    end

    it 'pre-fills user email' do
      url = service.authorization_url(redirect_uri: redirect_uri)
      params = CGI.parse(URI.parse(url).query)

      expect(params['stripe_user[email]']).to eq(['test@example.com'])
    end

    it 'sets business type to individual' do
      url = service.authorization_url(redirect_uri: redirect_uri)
      params = CGI.parse(URI.parse(url).query)

      expect(params['stripe_user[business_type]']).to eq(['individual'])
    end
  end

  describe '#connect_account' do
    let(:stripe_account_obj) { double('Stripe::Account', id: 'acct_123', email: 'stripe@example.com', type: 'express', charges_enabled: true, payouts_enabled: true) }
    let(:oauth_response) { double('Response', stripe_user_id: 'acct_123', access_token: 'sk_test_token', refresh_token: 'rt_test') }

    before do
      allow(Stripe::OAuth).to receive(:token).and_return(oauth_response)
      allow(Stripe::Account).to receive(:retrieve).and_return(stripe_account_obj)
    end

    it 'exchanges code for access token' do
      expect(Stripe::OAuth).to receive(:token).with(hash_including(
        grant_type: 'authorization_code',
        code: 'auth_code_123'
      ))

      service.connect_account(code: 'auth_code_123')
    end

    it 'retrieves account details' do
      expect(Stripe::Account).to receive(:retrieve).with('acct_123')

      service.connect_account(code: 'auth_code_123')
    end

    it 'creates or updates stripe account record' do
      expect(stripe_account).to receive(:update!).with(hash_including(
        stripe_id: 'acct_123',
        email: 'stripe@example.com',
        account_type: 'express',
        charges_enabled: true,
        payouts_enabled: true,
        access_token: 'sk_test_token',
        refresh_token: 'rt_test'
      ))

      service.connect_account(code: 'auth_code_123')
    end

    it 'logs OAuth errors' do
      allow(Stripe::OAuth).to receive(:token).and_raise(Stripe::OAuth::OAuthError.new('OAuth error'))

      expect(Rails.logger).to receive(:error).with(/Stripe OAuth error/)

      expect {
        service.connect_account(code: 'bad_code')
      }.to raise_error(Stripe::OAuth::OAuthError)
    end

    it 'logs Stripe errors' do
      allow(Stripe::OAuth).to receive(:token).and_return(oauth_response)
      allow(Stripe::Account).to receive(:retrieve).and_raise(Stripe::StripeError.new('Stripe error'))

      expect(Rails.logger).to receive(:error).with(/Stripe error during connect/)

      expect {
        service.connect_account(code: 'auth_code_123')
      }.to raise_error(Stripe::StripeError)
    end
  end

  describe '#disconnect_account' do
    let(:existing_stripe_account) { double('StripeAccount', stripe_id: 'acct_123', destroy: true) }

    before do
      allow(user).to receive(:stripe_account).and_return(existing_stripe_account)
    end

    it 'deauthorizes account in Stripe' do
      allow(Stripe::OAuth).to receive(:deauthorize).and_return(true)

      expect(Stripe::OAuth).to receive(:deauthorize).with(hash_including(
        client_id: 'ca_test123',
        stripe_user_id: 'acct_123'
      ))

      service.disconnect_account
    end

    it 'destroys local stripe account record' do
      allow(Stripe::OAuth).to receive(:deauthorize).and_return(true)

      expect(existing_stripe_account).to receive(:destroy)

      service.disconnect_account
    end

    it 'returns true on success' do
      allow(Stripe::OAuth).to receive(:deauthorize).and_return(true)

      expect(service.disconnect_account).to be true
    end

    it 'returns false if no stripe account exists' do
      allow(user).to receive(:stripe_account).and_return(nil)

      expect(service.disconnect_account).to be false
    end

    it 'returns false and logs error on Stripe error' do
      allow(Stripe::OAuth).to receive(:deauthorize).and_raise(Stripe::StripeError.new('Error'))

      expect(Rails.logger).to receive(:error).with(/Failed to disconnect Stripe/)

      expect(service.disconnect_account).to be false
    end
  end

  describe '#refresh_access_token' do
    let(:existing_stripe_account) { double('StripeAccount', refresh_token: 'rt_test', update!: true) }
    let(:refresh_response) { double('Response', access_token: 'new_access_token') }

    before do
      allow(user).to receive(:stripe_account).and_return(existing_stripe_account)
    end

    it 'refreshes access token' do
      allow(Stripe::OAuth).to receive(:token).and_return(refresh_response)

      expect(Stripe::OAuth).to receive(:token).with(hash_including(
        grant_type: 'refresh_token',
        refresh_token: 'rt_test'
      ))

      service.refresh_access_token
    end

    it 'updates access token in local record' do
      allow(Stripe::OAuth).to receive(:token).and_return(refresh_response)

      expect(existing_stripe_account).to receive(:update!).with(hash_including(
        access_token: 'new_access_token'
      ))

      service.refresh_access_token
    end

    it 'returns false if no stripe account' do
      allow(user).to receive(:stripe_account).and_return(nil)

      expect(service.refresh_access_token).to be false
    end

    it 'returns false if no refresh token' do
      allow(existing_stripe_account).to receive(:refresh_token).and_return(nil)

      expect(service.refresh_access_token).to be false
    end
  end

  describe '#create_account_link' do
    let(:existing_stripe_account) { double('StripeAccount', stripe_id: 'acct_123') }
    let(:account_link) { double('AccountLink', url: 'https://connect.stripe.com/setup/123') }

    before do
      allow(user).to receive(:stripe_account).and_return(existing_stripe_account)
    end

    it 'creates account onboarding link' do
      allow(Stripe::AccountLink).to receive(:create).and_return(account_link)

      expect(Stripe::AccountLink).to receive(:create).with(hash_including(
        account: 'acct_123',
        type: 'account_onboarding'
      ))

      service.create_account_link(return_url: 'https://myapp.com/return', refresh_url: 'https://myapp.com/refresh')
    end

    it 'returns account link URL' do
      allow(Stripe::AccountLink).to receive(:create).and_return(account_link)

      result = service.create_account_link(return_url: 'https://myapp.com/return', refresh_url: 'https://myapp.com/refresh')

      expect(result).to eq('https://connect.stripe.com/setup/123')
    end

    it 'returns nil if no stripe account' do
      allow(user).to receive(:stripe_account).and_return(nil)

      expect(service.create_account_link(return_url: 'url', refresh_url: 'url')).to be_nil
    end
  end

  describe '#onboarding_complete?' do
    it 'returns true when both charges and payouts are enabled' do
      stripe_acc = double('StripeAccount', charges_enabled: true, payouts_enabled: true)
      allow(user).to receive(:stripe_account).and_return(stripe_acc)

      expect(service.onboarding_complete?).to be true
    end

    it 'returns false when charges not enabled' do
      stripe_acc = double('StripeAccount', charges_enabled: false, payouts_enabled: true)
      allow(user).to receive(:stripe_account).and_return(stripe_acc)

      expect(service.onboarding_complete?).to be false
    end

    it 'returns false when payouts not enabled' do
      stripe_acc = double('StripeAccount', charges_enabled: true, payouts_enabled: false)
      allow(user).to receive(:stripe_account).and_return(stripe_acc)

      expect(service.onboarding_complete?).to be false
    end

    it 'returns false when no stripe account' do
      allow(user).to receive(:stripe_account).and_return(nil)

      expect(service.onboarding_complete?).to be false
    end
  end

  describe '#create_login_link' do
    let(:existing_stripe_account) { double('StripeAccount', stripe_id: 'acct_123') }
    let(:login_link) { double('LoginLink', url: 'https://connect.stripe.com/login/123') }

    before do
      allow(user).to receive(:stripe_account).and_return(existing_stripe_account)
    end

    it 'creates login link' do
      allow(Stripe::Account).to receive(:create_login_link).and_return(login_link)

      expect(Stripe::Account).to receive(:create_login_link).with('acct_123')

      service.create_login_link
    end

    it 'returns login link URL' do
      allow(Stripe::Account).to receive(:create_login_link).and_return(login_link)

      result = service.create_login_link

      expect(result).to eq('https://connect.stripe.com/login/123')
    end

    it 'returns nil if no stripe account' do
      allow(user).to receive(:stripe_account).and_return(nil)

      expect(service.create_login_link).to be_nil
    end
  end
end
