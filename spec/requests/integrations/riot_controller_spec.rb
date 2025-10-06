require 'rails_helper'

RSpec.describe Integrations::RiotController, type: :request do
  let(:user) { create(:user) }
  let(:riot_account) { create(:riot_account, user: user, game_name: 'TestPlayer', tag_line: 'NA1', region: 'na1') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/riot/connect' do
    let(:oauth_service) { instance_double(Integrations::RiotOauthService) }
    let(:auth_url) { 'https://auth.riotgames.com/authorize?client_id=test&redirect_uri=test&response_type=code&scope=openid&state=test123' }

    before do
      allow(Integrations::RiotOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:authorization_url).and_return(auth_url)
    end

    context 'when user is logged in' do
      it 'redirects to Riot Games OAuth URL' do
        get '/integrations/riot/connect'
        expect(response).to redirect_to(auth_url)
      end

      it 'stores region in session when provided' do
        get '/integrations/riot/connect', params: { region: 'euw1' }
        expect(session[:riot_region]).to eq('euw1')
      end

      it 'defaults to na1 region when not provided' do
        get '/integrations/riot/connect'
        expect(session[:riot_region]).to eq('na1')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/riot/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/riot/callback' do
    let(:oauth_service) { instance_double(Integrations::RiotOauthService) }
    let(:api_client) { instance_double(Integrations::RiotApiClient) }
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
        puuid: 'puuid-123-abc',
        gameName: 'TestPlayer',
        tagLine: 'NA1'
      }
    end

    before do
      allow(Integrations::RiotOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:exchange_code).with(code).and_return(tokens)
      allow(Integrations::RiotApiClient).to receive(:new).and_return(api_client)
      allow(api_client).to receive(:fetch_account_info).and_return(account_info)
    end

    context 'with valid authorization code' do
      it 'exchanges code for tokens' do
        expect(oauth_service).to receive(:exchange_code).with(code)
        get '/integrations/riot/callback', params: { code: code, region: 'na1' }
      end

      it 'creates a new Riot account' do
        expect {
          get '/integrations/riot/callback', params: { code: code, region: 'na1' }
        }.to change(RiotAccount, :count).by(1)
      end

      it 'stores account data correctly' do
        get '/integrations/riot/callback', params: { code: code, region: 'na1' }
        account = user.reload.riot_account
        expect(account.puuid).to eq('puuid-123-abc')
        expect(account.game_name).to eq('TestPlayer')
        expect(account.tag_line).to eq('NA1')
        expect(account.region).to eq('na1')
        expect(account.access_token).to eq(access_token)
        expect(account.refresh_token).to eq(refresh_token)
      end

      it 'updates existing Riot account' do
        riot_account # Create existing account
        expect {
          get '/integrations/riot/callback', params: { code: code, region: 'euw1' }
        }.not_to change(RiotAccount, :count)

        account = user.reload.riot_account
        expect(account.region).to eq('euw1')
      end

      it 'redirects to settings with success message' do
        get '/integrations/riot/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Riot connected successfully')
      end

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later)
        get '/integrations/riot/callback', params: { code: code }
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/riot/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Riot authorization failed')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/riot/callback'
        }.not_to change(RiotAccount, :count)
      end
    end

    context 'when OAuth exchange fails' do
      before do
        allow(oauth_service).to receive(:exchange_code).and_raise(StandardError.new('OAuth error'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/riot/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to connect Riot account')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/riot/callback', params: { code: code }
        }.not_to change(RiotAccount, :count)
      end
    end

    context 'when API client fails' do
      before do
        allow(api_client).to receive(:fetch_account_info).and_raise(StandardError.new('API error'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/riot/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to connect Riot account')
      end
    end
  end

  describe 'DELETE /integrations/riot/disconnect' do
    context 'when Riot account exists' do
      before { riot_account }

      it 'destroys the Riot account' do
        expect {
          delete '/integrations/riot/disconnect'
        }.to change(RiotAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/riot/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Riot account disconnected')
      end
    end

    context 'when Riot account does not exist' do
      it 'does not raise error' do
        expect {
          delete '/integrations/riot/disconnect'
        }.not_to raise_error
      end

      it 'redirects to settings' do
        delete '/integrations/riot/disconnect'
        expect(response).to redirect_to(settings_path)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/riot/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/riot/sync' do
    context 'when Riot account exists' do
      before { riot_account }

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later).with(
          riot_account.id,
          'RiotAccount'
        )
        post '/integrations/riot/sync'
      end

      it 'redirects to settings with success message' do
        allow(Integrations::BaseSyncJob).to receive(:perform_later)
        post '/integrations/riot/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Riot sync started')
      end
    end

    context 'when Riot account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/riot/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Riot account connected')
      end

      it 'does not enqueue sync job' do
        expect(Integrations::BaseSyncJob).not_to receive(:perform_later)
        post '/integrations/riot/sync'
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/riot/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
