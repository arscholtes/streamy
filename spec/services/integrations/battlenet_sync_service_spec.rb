require 'rails_helper'

RSpec.describe Integrations::BattlenetSyncService, type: :service do
  let(:user) { double('User', id: 1, metadata: {}) }
  let(:battlenet_account) do
    double('BattlenetAccount',
      id: 1,
      user: user,
      update!: true
    )
  end
  let(:api_client) { instance_double(Integrations::BattlenetApiClient) }
  let(:service) { described_class.new(battlenet_account) }

  before do
    allow(Integrations::BattlenetApiClient).to receive(:new).and_return(api_client)
  end

  describe '#initialize' do
    it 'sets the battlenet account' do
      expect(service.battlenet_account).to eq(battlenet_account)
    end

    it 'creates API client' do
      expect(Integrations::BattlenetApiClient).to have_received(:new).with(battlenet_account)
    end
  end

  describe '#sync!' do
    let(:account_info) { { battletag: 'TestUser#1234' } }

    before do
      allow(api_client).to receive(:fetch_account_info).and_return(account_info)
      allow(service).to receive(:sync_game_profiles)
    end

    it 'syncs account info' do
      expect(battlenet_account).to receive(:update!).with(hash_including(battletag: 'TestUser#1234'))

      service.sync!
    end

    it 'syncs game profiles' do
      expect(service).to receive(:sync_game_profiles)

      service.sync!
    end

    it 'updates last_synced_at timestamp' do
      expect(battlenet_account).to receive(:update!).with(hash_including(:last_synced_at))

      service.sync!
    end

    it 'wraps sync in transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_yield

      service.sync!
    end

    it 'logs and raises API errors' do
      allow(api_client).to receive(:fetch_account_info)
        .and_raise(Integrations::APIError, 'API error')

      expect(Rails.logger).to receive(:error).with(/Battle.net sync failed/)

      expect {
        service.sync!
      }.to raise_error(Integrations::APIError)
    end
  end

  describe '#sync_wow_profile' do
    let(:wow_data) do
      {
        wow_accounts: [
          {
            id: 123,
            characters: [
              {
                name: 'TestChar',
                realm: { name: 'TestRealm' },
                level: 70,
                playable_class: { name: 'Warrior' },
                playable_race: { name: 'Human' }
              }
            ]
          }
        ]
      }
    end

    before do
      allow(service).to receive(:has_wow_access?).and_return(true)
      allow(api_client).to receive(:fetch_wow_profile).and_return(wow_data)
      allow(user).to receive(:update)
    end

    it 'fetches WoW profile data' do
      expect(api_client).to receive(:fetch_wow_profile)

      service.send(:sync_wow_profile)
    end

    it 'stores WoW profile in user metadata' do
      expect(user).to receive(:update) do |args|
        wow_profile = args[:metadata][:wow_profile]
        expect(wow_profile[:accounts]).to be_an(Array)
        expect(wow_profile[:accounts].first[:id]).to eq(123)
        expect(wow_profile[:accounts].first[:characters].first[:name]).to eq('TestChar')
      end

      service.send(:sync_wow_profile)
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:fetch_wow_profile)
        .and_raise(Integrations::APIError, 'WoW API error')

      expect(Rails.logger).to receive(:warn).with(/Could not sync WoW profile/)

      expect {
        service.send(:sync_wow_profile)
      }.not_to raise_error
    end
  end

  describe '#sync_diablo_profile' do
    let(:diablo_data) do
      {
        heroes: [
          { name: 'TestHero', class: 'wizard', level: 70 }
        ]
      }
    end

    before do
      allow(service).to receive(:has_diablo_access?).and_return(true)
      allow(api_client).to receive(:fetch_diablo_profile).and_return(diablo_data)
      allow(user).to receive(:update)
    end

    it 'fetches Diablo profile data' do
      expect(api_client).to receive(:fetch_diablo_profile)

      service.send(:sync_diablo_profile)
    end

    it 'stores Diablo profile in user metadata' do
      expect(user).to receive(:update) do |args|
        diablo_profile = args[:metadata][:diablo_profile]
        expect(diablo_profile[:data]).to eq(diablo_data)
      end

      service.send(:sync_diablo_profile)
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:fetch_diablo_profile)
        .and_raise(Integrations::APIError, 'Diablo API error')

      expect(Rails.logger).to receive(:warn).with(/Could not sync Diablo profile/)

      expect {
        service.send(:sync_diablo_profile)
      }.not_to raise_error
    end
  end

  describe '#sync_sc2_profile' do
    let(:sc2_data) do
      {
        summary: [
          { id: '123', displayName: 'TestPlayer' }
        ]
      }
    end

    before do
      allow(service).to receive(:has_sc2_access?).and_return(true)
      allow(api_client).to receive(:fetch_sc2_profile).and_return(sc2_data)
      allow(user).to receive(:update)
    end

    it 'fetches StarCraft 2 profile data' do
      expect(api_client).to receive(:fetch_sc2_profile)

      service.send(:sync_sc2_profile)
    end

    it 'stores SC2 profile in user metadata' do
      expect(user).to receive(:update) do |args|
        sc2_profile = args[:metadata][:sc2_profile]
        expect(sc2_profile[:data]).to eq(sc2_data)
      end

      service.send(:sync_sc2_profile)
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:fetch_sc2_profile)
        .and_raise(Integrations::APIError, 'SC2 API error')

      expect(Rails.logger).to receive(:warn).with(/Could not sync SC2 profile/)

      expect {
        service.send(:sync_sc2_profile)
      }.not_to raise_error
    end
  end

  describe 'game access checks' do
    it 'has_wow_access? returns true by default' do
      expect(service.send(:has_wow_access?)).to be true
    end

    it 'has_diablo_access? returns true by default' do
      expect(service.send(:has_diablo_access?)).to be true
    end

    it 'has_sc2_access? returns true by default' do
      expect(service.send(:has_sc2_access?)).to be true
    end
  end
end
