require 'rails_helper'

RSpec.describe Integrations::SteamSyncService, type: :service do
  let(:steam_account) do
    double('SteamAccount',
      id: 1,
      steam_id: '76561197960435530',
      update!: true
    )
  end
  let(:api_client) { instance_double(Integrations::SteamApiClient) }
  let(:oauth_service) { instance_double(Integrations::SteamOauthService) }
  let(:service) { described_class.new(steam_account) }

  before do
    allow(Integrations::SteamApiClient).to receive(:new).and_return(api_client)
    allow(Integrations::SteamOauthService).to receive(:new).and_return(oauth_service)
  end

  describe '#initialize' do
    it 'sets the steam account' do
      expect(service.steam_account).to eq(steam_account)
    end

    it 'creates API client' do
      expect(Integrations::SteamApiClient).to have_received(:new).with(steam_account)
    end

    it 'creates OAuth service' do
      expect(Integrations::SteamOauthService).to have_received(:new)
    end
  end

  describe '#sync!' do
    before do
      allow(service).to receive(:sync_profile)
      allow(service).to receive(:sync_steam_level)
    end

    it 'syncs profile' do
      expect(service).to receive(:sync_profile)
      service.sync!
    end

    it 'syncs Steam level' do
      expect(service).to receive(:sync_steam_level)
      service.sync!
    end

    it 'updates last_synced_at' do
      expect(steam_account).to receive(:update!).with(hash_including(:last_synced_at))
      service.sync!
    end

    it 'wraps in transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_yield
      service.sync!
    end

    it 'logs and raises API errors' do
      allow(service).to receive(:sync_profile)
        .and_raise(Integrations::APIError, 'API error')

      expect(Rails.logger).to receive(:error).with(/Steam sync failed/)

      expect {
        service.sync!
      }.to raise_error(Integrations::APIError)
    end
  end

  describe '#sync_profile' do
    let(:profile_data) do
      {
        persona_name: 'TestPlayer',
        profile_url: 'https://steamcommunity.com/id/test/',
        avatar_url: 'https://avatar.url',
        real_name: 'Test User',
        country_code: 'US',
        state_code: 'CA',
        visibility: 3,
        time_created: 1234567890,
        last_logoff: 1234567900
      }
    end

    before do
      allow(oauth_service).to receive(:fetch_user_data).and_return(profile_data)
    end

    it 'fetches and updates profile data' do
      expect(steam_account).to receive(:update!).with(hash_including(
        persona_name: 'TestPlayer',
        profile_url: 'https://steamcommunity.com/id/test/',
        avatar_url: 'https://avatar.url',
        real_name: 'Test User',
        country_code: 'US',
        state_code: 'CA',
        visibility: 3,
        time_created: 1234567890,
        last_logoff: 1234567900
      ))

      service.send(:sync_profile)
    end

    it 'uses Steam ID from account' do
      expect(oauth_service).to receive(:fetch_user_data).with('76561197960435530')
      service.send(:sync_profile)
    end
  end

  describe '#sync_steam_level' do
    let(:level_data) do
      { 'response' => { 'player_level' => 42 } }
    end

    before do
      allow(api_client).to receive(:get_steam_level).and_return(level_data)
    end

    it 'fetches and updates Steam level' do
      expect(steam_account).to receive(:update!).with(hash_including(level: 42))
      service.send(:sync_steam_level)
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:get_steam_level)
        .and_raise(Integrations::APIError, 'API error')

      expect(Rails.logger).to receive(:warn).with(/Could not fetch Steam level/)

      expect {
        service.send(:sync_steam_level)
      }.not_to raise_error
    end

    it 'handles nil response' do
      allow(api_client).to receive(:get_steam_level).and_return(nil)

      expect {
        service.send(:sync_steam_level)
      }.not_to raise_error
    end

    it 'handles response without player_level' do
      allow(api_client).to receive(:get_steam_level).and_return({ 'response' => {} })

      expect {
        service.send(:sync_steam_level)
      }.not_to raise_error
    end
  end
end
