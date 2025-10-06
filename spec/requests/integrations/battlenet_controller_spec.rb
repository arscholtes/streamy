require 'rails_helper'

RSpec.describe Integrations::BattlenetController, type: :request do
  let(:user) { create(:user) }
  let(:battlenet_account) { create(:battlenet_account, user: user, battletag: 'TestUser#1234', region: 'us') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/battlenet/connect' do
    let(:oauth_service) { instance_double(Integrations::BattlenetOauthService) }
    let(:auth_url) { 'https://oauth.battle.net/authorize?client_id=test&redirect_uri=test&response_type=code&scope=openid&state=test123' }

    before do
      allow(Integrations::BattlenetOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:authorization_url).and_return(auth_url)
    end

    context 'when user is logged in' do
      it 'redirects to Battle.net OAuth URL' do
        get '/integrations/battlenet/connect'
        expect(response).to redirect_to(auth_url)
      end

      it 'stores region in session when provided' do
        get '/integrations/battlenet/connect', params: { region: 'eu' }
        expect(session[:battlenet_region]).to eq('eu')
      end

      it 'defaults to US region when not provided' do
        get '/integrations/battlenet/connect'
        expect(session[:battlenet_region]).to eq('us')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/battlenet/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/battlenet/callback' do
    let(:oauth_service) { instance_double(Integrations::BattlenetOauthService) }
    let(:api_client) { instance_double(Integrations::BattlenetApiClient) }
    let(:code) { 'auth_code_123' }
    let(:access_token) { 'access_token_abc' }
    let(:refresh_token) { 'refresh_token_xyz' }
    let(:tokens) do
      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: 3600
      }
    end
    let(:account_info) do
      {
        battletag: 'TestUser#1234'
      }
    end

    before do
      allow(Integrations::BattlenetOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:exchange_code).with(code).and_return(tokens)
      allow(Integrations::BattlenetApiClient).to receive(:new).and_return(api_client)
      allow(api_client).to receive(:fetch_account_info).and_return(account_info)
    end

    context 'with valid authorization code' do
      it 'exchanges code for tokens' do
        expect(oauth_service).to receive(:exchange_code).with(code)
        get '/integrations/battlenet/callback', params: { code: code, region: 'us' }
      end

      it 'creates a new Battle.net account' do
        expect {
          get '/integrations/battlenet/callback', params: { code: code, region: 'us' }
        }.to change(BattlenetAccount, :count).by(1)
      end

      it 'stores account data correctly' do
        get '/integrations/battlenet/callback', params: { code: code, region: 'us' }
        account = user.reload.battlenet_account
        expect(account.battletag).to eq('TestUser#1234')
        expect(account.region).to eq('us')
        expect(account.access_token).to eq(access_token)
        expect(account.refresh_token).to eq(refresh_token)
      end

      it 'updates existing Battle.net account' do
        battlenet_account # Create existing account
        expect {
          get '/integrations/battlenet/callback', params: { code: code, region: 'eu' }
        }.not_to change(BattlenetAccount, :count)

        account = user.reload.battlenet_account
        expect(account.region).to eq('eu')
      end

      it 'redirects to settings with success message' do
        get '/integrations/battlenet/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Battlenet connected successfully')
      end

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later)
        get '/integrations/battlenet/callback', params: { code: code }
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/battlenet/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Battlenet authorization failed')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/battlenet/callback'
        }.not_to change(BattlenetAccount, :count)
      end
    end

    context 'when OAuth exchange fails' do
      before do
        allow(oauth_service).to receive(:exchange_code).and_raise(StandardError.new('OAuth error'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/battlenet/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to connect Battlenet account')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/battlenet/callback', params: { code: code }
        }.not_to change(BattlenetAccount, :count)
      end
    end

    context 'when API client fails' do
      before do
        allow(api_client).to receive(:fetch_account_info).and_raise(StandardError.new('API error'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/battlenet/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to connect Battlenet account')
      end
    end
  end

  describe 'DELETE /integrations/battlenet/disconnect' do
    context 'when Battle.net account exists' do
      before { battlenet_account }

      it 'destroys the Battle.net account' do
        expect {
          delete '/integrations/battlenet/disconnect'
        }.to change(BattlenetAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/battlenet/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Battlenet account disconnected')
      end
    end

    context 'when Battle.net account does not exist' do
      it 'does not raise error' do
        expect {
          delete '/integrations/battlenet/disconnect'
        }.not_to raise_error
      end

      it 'redirects to settings' do
        delete '/integrations/battlenet/disconnect'
        expect(response).to redirect_to(settings_path)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/battlenet/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/battlenet/sync' do
    context 'when Battle.net account exists' do
      before { battlenet_account }

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later).with(
          battlenet_account.id,
          'BattlenetAccount'
        )
        post '/integrations/battlenet/sync'
      end

      it 'redirects to settings with success message' do
        allow(Integrations::BaseSyncJob).to receive(:perform_later)
        post '/integrations/battlenet/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Battlenet sync started')
      end
    end

    context 'when Battle.net account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/battlenet/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Battlenet account connected')
      end

      it 'does not enqueue sync job' do
        expect(Integrations::BaseSyncJob).not_to receive(:perform_later)
        post '/integrations/battlenet/sync'
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/battlenet/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
