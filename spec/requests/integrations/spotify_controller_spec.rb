require 'rails_helper'

RSpec.describe Integrations::SpotifyController, type: :request do
  let(:user) { create(:user) }
  let(:spotify_account) { create(:spotify_account, user: user, spotify_id: 'spotify123', display_name: 'TestUser') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/spotify/connect' do
    let(:oauth_service) { instance_double(Integrations::SpotifyOauthService) }
    let(:auth_url) { 'https://accounts.spotify.com/authorize?client_id=test&redirect_uri=test&response_type=code&scope=user-read-email&state=test123' }

    before do
      allow(Integrations::SpotifyOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:authorization_url).and_return(auth_url)
    end

    context 'when user is logged in' do
      it 'redirects to Spotify OAuth URL' do
        get '/integrations/spotify/connect'
        expect(response).to redirect_to(auth_url)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/spotify/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/spotify/callback' do
    let(:oauth_service) { instance_double(Integrations::SpotifyOauthService) }
    let(:api_client) { instance_double(Integrations::SpotifyApiClient) }
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
    let(:profile) do
      {
        id: 'spotify123',
        display_name: 'TestUser',
        email: 'test@example.com',
        product: 'premium',
        country: 'US',
        followers: { total: 42 }
      }
    end

    before do
      allow(Integrations::SpotifyOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:exchange_code).with(code).and_return(tokens)
      allow(Integrations::SpotifyApiClient).to receive(:new).and_return(api_client)
      allow(api_client).to receive(:fetch_user_profile).and_return(profile)
    end

    context 'with valid authorization code' do
      it 'exchanges code for tokens' do
        expect(oauth_service).to receive(:exchange_code).with(code)
        get '/integrations/spotify/callback', params: { code: code }
      end

      it 'creates a new Spotify account' do
        expect {
          get '/integrations/spotify/callback', params: { code: code }
        }.to change(SpotifyAccount, :count).by(1)
      end

      it 'stores account data correctly' do
        get '/integrations/spotify/callback', params: { code: code }
        account = user.reload.spotify_account
        expect(account.spotify_id).to eq('spotify123')
        expect(account.display_name).to eq('TestUser')
        expect(account.email).to eq('test@example.com')
        expect(account.product).to eq('premium')
        expect(account.country).to eq('US')
        expect(account.follower_count).to eq(42)
        expect(account.access_token).to eq(access_token)
        expect(account.refresh_token).to eq(refresh_token)
      end

      it 'updates existing Spotify account' do
        spotify_account # Create existing account
        expect {
          get '/integrations/spotify/callback', params: { code: code }
        }.not_to change(SpotifyAccount, :count)
      end

      it 'redirects to settings with success message' do
        get '/integrations/spotify/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Spotify connected successfully')
      end

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later)
        get '/integrations/spotify/callback', params: { code: code }
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/spotify/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Spotify authorization failed')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/spotify/callback'
        }.not_to change(SpotifyAccount, :count)
      end
    end

    context 'when OAuth exchange fails' do
      before do
        allow(oauth_service).to receive(:exchange_code).and_raise(StandardError.new('OAuth error'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/spotify/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to connect Spotify account')
      end
    end
  end

  describe 'DELETE /integrations/spotify/disconnect' do
    context 'when Spotify account exists' do
      before { spotify_account }

      it 'destroys the Spotify account' do
        expect {
          delete '/integrations/spotify/disconnect'
        }.to change(SpotifyAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/spotify/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Spotify account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/spotify/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/spotify/sync' do
    context 'when Spotify account exists' do
      before { spotify_account }

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later).with(
          spotify_account.id,
          'SpotifyAccount'
        )
        post '/integrations/spotify/sync'
      end

      it 'redirects to settings with success message' do
        allow(Integrations::BaseSyncJob).to receive(:perform_later)
        post '/integrations/spotify/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Spotify sync started')
      end
    end

    context 'when Spotify account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/spotify/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Spotify account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/spotify/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
