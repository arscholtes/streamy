require 'rails_helper'

RSpec.describe Integrations::DiscordController, type: :request do
  let(:user) { create(:user) }
  let(:discord_account) { create(:discord_account, user: user, username: 'TestUser', discord_id: '123456789') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/discord/connect' do
    let(:oauth_service) { instance_double(Integrations::DiscordOauthService) }
    let(:auth_url) { 'https://discord.com/api/oauth2/authorize?client_id=test&redirect_uri=test&response_type=code&scope=identify%20email&state=test123' }

    before do
      allow(Integrations::DiscordOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:authorization_url).and_return(auth_url)
    end

    context 'when user is logged in' do
      it 'redirects to Discord OAuth URL' do
        get '/integrations/discord/connect'
        expect(response).to redirect_to(auth_url)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/discord/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/discord/callback' do
    let(:oauth_service) { instance_double(Integrations::DiscordOauthService) }
    let(:api_client) { instance_double(Integrations::DiscordApiClient) }
    let(:code) { 'auth_code_123' }
    let(:access_token) { 'access_token_abc' }
    let(:refresh_token) { 'refresh_token_xyz' }
    let(:tokens) do
      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: 604800
      }
    end
    let(:user_profile) do
      {
        id: '123456789',
        username: 'TestUser',
        discriminator: '1234',
        avatar: 'avatar_hash',
        email: 'test@example.com',
        verified: true,
        locale: 'en-US'
      }
    end

    before do
      allow(Integrations::DiscordOauthService).to receive(:new).and_return(oauth_service)
      allow(oauth_service).to receive(:exchange_code).with(code).and_return(tokens)
      allow(Integrations::DiscordApiClient).to receive(:new).and_return(api_client)
      allow(api_client).to receive(:fetch_user_profile).and_return(user_profile)
    end

    context 'with valid authorization code' do
      it 'exchanges code for tokens' do
        expect(oauth_service).to receive(:exchange_code).with(code)
        get '/integrations/discord/callback', params: { code: code }
      end

      it 'creates a new Discord account' do
        expect {
          get '/integrations/discord/callback', params: { code: code }
        }.to change(DiscordAccount, :count).by(1)
      end

      it 'stores account data correctly' do
        get '/integrations/discord/callback', params: { code: code }
        account = user.reload.discord_account
        expect(account.discord_id).to eq('123456789')
        expect(account.username).to eq('TestUser')
        expect(account.discriminator).to eq('1234')
        expect(account.email).to eq('test@example.com')
        expect(account.verified).to eq(true)
        expect(account.locale).to eq('en-US')
        expect(account.access_token).to eq(access_token)
        expect(account.refresh_token).to eq(refresh_token)
      end

      it 'sets avatar URL correctly' do
        get '/integrations/discord/callback', params: { code: code }
        account = user.reload.discord_account
        expect(account.avatar_url).to eq('https://cdn.discordapp.com/avatars/123456789/avatar_hash.png')
      end

      it 'handles missing avatar' do
        user_profile[:avatar] = nil
        get '/integrations/discord/callback', params: { code: code }
        account = user.reload.discord_account
        expect(account.avatar_url).to be_nil
      end

      it 'updates existing Discord account' do
        discord_account # Create existing account
        expect {
          get '/integrations/discord/callback', params: { code: code }
        }.not_to change(DiscordAccount, :count)

        account = user.reload.discord_account
        expect(account.username).to eq('TestUser')
      end

      it 'redirects to settings with success message' do
        get '/integrations/discord/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Discord connected successfully')
      end

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later)
        get '/integrations/discord/callback', params: { code: code }
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/discord/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Discord authorization failed')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/discord/callback'
        }.not_to change(DiscordAccount, :count)
      end
    end

    context 'when OAuth exchange fails' do
      before do
        allow(oauth_service).to receive(:exchange_code).and_raise(StandardError.new('OAuth error'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/discord/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to connect Discord account')
      end

      it 'does not create an account' do
        expect {
          get '/integrations/discord/callback', params: { code: code }
        }.not_to change(DiscordAccount, :count)
      end
    end

    context 'when API client fails' do
      before do
        allow(api_client).to receive(:fetch_user_profile).and_raise(StandardError.new('API error'))
      end

      it 'redirects to settings with error message' do
        get '/integrations/discord/callback', params: { code: code }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to connect Discord account')
      end
    end
  end

  describe 'DELETE /integrations/discord/disconnect' do
    context 'when Discord account exists' do
      before { discord_account }

      it 'destroys the Discord account' do
        expect {
          delete '/integrations/discord/disconnect'
        }.to change(DiscordAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/discord/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Discord account disconnected')
      end
    end

    context 'when Discord account does not exist' do
      it 'does not raise error' do
        expect {
          delete '/integrations/discord/disconnect'
        }.not_to raise_error
      end

      it 'redirects to settings' do
        delete '/integrations/discord/disconnect'
        expect(response).to redirect_to(settings_path)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/discord/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/discord/sync' do
    context 'when Discord account exists' do
      before { discord_account }

      it 'enqueues sync job' do
        expect(Integrations::BaseSyncJob).to receive(:perform_later).with(
          discord_account.id,
          'DiscordAccount'
        )
        post '/integrations/discord/sync'
      end

      it 'redirects to settings with success message' do
        allow(Integrations::BaseSyncJob).to receive(:perform_later)
        post '/integrations/discord/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Discord sync started')
      end
    end

    context 'when Discord account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/discord/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Discord account connected')
      end

      it 'does not enqueue sync job' do
        expect(Integrations::BaseSyncJob).not_to receive(:perform_later)
        post '/integrations/discord/sync'
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/discord/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'PUT /integrations/discord/update_privacy_settings' do
    let(:privacy_setting) { instance_double(IntegrationPrivacySetting, settings: {}, update!: true) }

    before do
      discord_account
      allow_any_instance_of(DiscordAccount).to receive(:integration_privacy_setting).and_return(privacy_setting)
    end

    context 'when Discord account exists' do
      it 'updates privacy settings' do
        privacy_settings = { 'show_username' => 'true', 'show_discriminator' => 'false' }
        expect(privacy_setting).to receive(:update!).with(
          settings: { 'show_username' => true, 'show_discriminator' => false }
        )
        put '/integrations/discord/update_privacy_settings', params: { privacy_settings: privacy_settings }
      end

      it 'redirects to settings with success message' do
        put '/integrations/discord/update_privacy_settings', params: { privacy_settings: {} }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to eq('Discord privacy settings updated successfully!')
      end
    end

    context 'when update fails' do
      before do
        allow(privacy_setting).to receive(:update!).and_raise(StandardError.new('Update failed'))
      end

      it 'redirects with error message' do
        put '/integrations/discord/update_privacy_settings', params: { privacy_settings: {} }
        expect(response).to redirect_to(integrations_discord_privacy_settings_path)
        expect(flash[:alert]).to include('Failed to update settings')
      end
    end

    context 'when Discord account does not exist' do
      before do
        user.discord_account&.destroy
      end

      it 'redirects to settings with alert' do
        put '/integrations/discord/update_privacy_settings', params: { privacy_settings: {} }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq('Discord account not connected')
      end
    end
  end
end
