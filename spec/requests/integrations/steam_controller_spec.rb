require 'rails_helper'

RSpec.describe Integrations::SteamController, type: :request do
  let(:user) { create(:user) }
  let(:steam_account) { create(:steam_account, user: user, steam_id: '76561198012345678', persona_name: 'TestGamer') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/steam/connect' do
    let(:oauth_service) { instance_double(SteamOauthService) }
    let(:auth_url) { 'https://steamcommunity.com/openid/login?openid.ns=http://specs.openid.net/auth/2.0' }

    before do
      allow(SteamOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:authorize_url).and_return(auth_url)
    end

    context 'when user is logged in' do
      it 'redirects to Steam OpenID URL' do
        get '/integrations/steam/connect'
        expect(response).to redirect_to(auth_url)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/steam/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/steam/callback' do
    let(:oauth_service) { instance_double(SteamOauthService) }
    let(:steam_id) { '76561198012345678' }
    let(:user_data) do
      {
        steam_id: steam_id,
        persona_name: 'TestGamer',
        profile_url: 'https://steamcommunity.com/id/testgamer/',
        avatar_url: 'https://avatar.url/test.jpg',
        real_name: 'Test User',
        country_code: 'US',
        state_code: 'CA',
        visibility: 3,
        time_created: Time.now.to_i,
        last_logoff: Time.now.to_i
      }
    end
    let(:tokens) do
      {
        access_token: 'pseudo_token_abc',
        refresh_token: 'pseudo_refresh_xyz',
        expires_at: 1.year.from_now
      }
    end

    before do
      allow(SteamOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:verify_and_extract_steam_id).and_return(steam_id)
      allow(oauth_service).to receive(:fetch_user_data).with(steam_id).and_return(user_data)
      allow(oauth_service).to receive(:generate_pseudo_tokens).with(steam_id).and_return(tokens)
    end

    context 'with valid OpenID response' do
      it 'verifies and extracts Steam ID' do
        expect(oauth_service).to receive(:verify_and_extract_steam_id)
        get '/integrations/steam/callback', params: { 'openid.claimed_id' => "https://steamcommunity.com/openid/id/#{steam_id}" }
      end

      it 'creates a new Steam account' do
        expect {
          get '/integrations/steam/callback', params: { 'openid.claimed_id' => "https://steamcommunity.com/openid/id/#{steam_id}" }
        }.to change(SteamAccount, :count).by(1)
      end

      it 'stores account data correctly' do
        get '/integrations/steam/callback', params: { 'openid.claimed_id' => "https://steamcommunity.com/openid/id/#{steam_id}" }
        account = user.reload.steam_account
        expect(account.steam_id).to eq(steam_id)
        expect(account.persona_name).to eq('TestGamer')
        expect(account.profile_url).to eq('https://steamcommunity.com/id/testgamer/')
        expect(account.avatar_url).to eq('https://avatar.url/test.jpg')
        expect(account.real_name).to eq('Test User')
        expect(account.country_code).to eq('US')
      end

      it 'updates existing Steam account' do
        steam_account # Create existing account
        expect {
          get '/integrations/steam/callback', params: { 'openid.claimed_id' => "https://steamcommunity.com/openid/id/#{steam_id}" }
        }.not_to change(SteamAccount, :count)

        account = user.reload.steam_account
        expect(account.persona_name).to eq('TestGamer')
      end

      it 'redirects to privacy settings with success message' do
        get '/integrations/steam/callback', params: { 'openid.claimed_id' => "https://steamcommunity.com/openid/id/#{steam_id}" }
        expect(response).to redirect_to(integrations_steam_privacy_settings_path)
        expect(flash[:notice]).to eq('Steam account connected successfully!')
      end
    end

    context 'when authentication fails' do
      before do
        allow(oauth_service).to receive(:verify_and_extract_steam_id).and_raise(Integrations::AuthenticationError.new('Invalid OpenID response'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/steam/callback', params: { 'openid.claimed_id' => "invalid" }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to include('Steam authentication failed')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/steam/callback', params: { 'openid.claimed_id' => "invalid" }
        }.not_to change(SteamAccount, :count)
      end
    end

    context 'when API error occurs' do
      before do
        allow(oauth_service).to receive(:fetch_user_data).and_raise(Integrations::APIError.new('API request failed'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/steam/callback', params: { 'openid.claimed_id' => "https://steamcommunity.com/openid/id/#{steam_id}" }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to include('Failed to connect Steam account')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(oauth_service).to receive(:verify_and_extract_steam_id).and_raise(StandardError.new('Unexpected error'))
      end

      it 'redirects to settings with generic error message' do
        get '/integrations/steam/callback', params: { 'openid.claimed_id' => "invalid" }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq('An unexpected error occurred. Please try again.')
      end
    end
  end

  describe 'DELETE /integrations/steam/disconnect' do
    context 'when Steam account exists' do
      before { steam_account }

      it 'destroys the Steam account' do
        expect {
          delete '/integrations/steam/disconnect'
        }.to change(SteamAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/steam/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Steam account disconnected')
      end
    end

    context 'when Steam account does not exist' do
      it 'does not raise error' do
        expect {
          delete '/integrations/steam/disconnect'
        }.not_to raise_error
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/steam/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/steam/sync' do
    context 'when Steam account exists' do
      before { steam_account }

      it 'enqueues sync job' do
        expect(SteamSyncJob).to receive(:perform_later).with(steam_account.id)
        post '/integrations/steam/sync'
      end

      it 'redirects to settings with success message' do
        allow(SteamSyncJob).to receive(:perform_later)
        post '/integrations/steam/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Steam sync started')
      end
    end

    context 'when Steam account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/steam/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq('Steam account not connected')
      end

      it 'does not enqueue sync job' do
        expect(SteamSyncJob).not_to receive(:perform_later)
        post '/integrations/steam/sync'
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/steam/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'PUT /integrations/steam/update_privacy_settings' do
    let(:privacy_setting) { instance_double(IntegrationPrivacySetting, settings: {}, update!: true) }

    before do
      steam_account
      allow_any_instance_of(SteamAccount).to receive(:integration_privacy_setting).and_return(privacy_setting)
    end

    context 'when Steam account exists' do
      it 'updates privacy settings' do
        privacy_settings = { 'show_persona_name' => 'true', 'show_real_name' => 'false' }
        expect(privacy_setting).to receive(:update!).with(
          settings: { 'show_persona_name' => true, 'show_real_name' => false }
        )
        put '/integrations/steam/update_privacy_settings', params: { privacy_settings: privacy_settings }
      end

      it 'redirects to settings with success message' do
        put '/integrations/steam/update_privacy_settings', params: { privacy_settings: {} }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to eq('Steam privacy settings updated successfully!')
      end
    end

    context 'when update fails' do
      before do
        allow(privacy_setting).to receive(:update!).and_raise(StandardError.new('Update failed'))
      end

      it 'redirects with error message' do
        put '/integrations/steam/update_privacy_settings', params: { privacy_settings: {} }
        expect(response).to redirect_to(integrations_steam_privacy_settings_path)
        expect(flash[:alert]).to include('Failed to update settings')
      end
    end

    context 'when Steam account does not exist' do
      before do
        user.steam_account&.destroy
      end

      it 'redirects to settings with alert' do
        put '/integrations/steam/update_privacy_settings', params: { privacy_settings: {} }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq('Steam account not connected')
      end
    end
  end
end
