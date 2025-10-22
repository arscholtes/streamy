require 'rails_helper'

RSpec.describe Integrations::RiotSyncService, type: :service do
  let(:user) { double('User', id: 1, metadata: {}) }
  let(:riot_account) do
    double('RiotAccount',
      id: 1,
      user: user,
      puuid: 'test_puuid',
      update!: true
    )
  end
  let(:api_client) { instance_double(Integrations::RiotApiClient) }
  let(:service) { described_class.new(riot_account) }

  before do
    allow(Integrations::RiotApiClient).to receive(:new).and_return(api_client)
  end

  describe '#initialize' do
    it 'sets the riot account' do
      expect(service.riot_account).to eq(riot_account)
    end

    it 'creates API client' do
      # Create a new service to test initialization
      new_service = described_class.new(riot_account)
      expect(Integrations::RiotApiClient).to have_received(:new).with(riot_account)
    end
  end

  describe '#sync!' do
    before do
      allow(service).to receive(:sync_account_info)
      allow(service).to receive(:sync_league_of_legends)
      allow(service).to receive(:sync_teamfight_tactics)
      allow(service).to receive(:sync_valorant)
    end

    it 'syncs account info' do
      expect(service).to receive(:sync_account_info)
      service.sync!
    end

    it 'syncs League of Legends data' do
      expect(service).to receive(:sync_league_of_legends)
      service.sync!
    end

    it 'syncs Teamfight Tactics data' do
      expect(service).to receive(:sync_teamfight_tactics)
      service.sync!
    end

    it 'syncs Valorant data' do
      expect(service).to receive(:sync_valorant)
      service.sync!
    end

    it 'updates last_synced_at' do
      expect(riot_account).to receive(:update!).with(hash_including(:last_synced_at))
      service.sync!
    end

    it 'wraps in transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_yield
      service.sync!
    end

    it 'logs and raises API errors' do
      allow(service).to receive(:sync_account_info)
        .and_raise(Integrations::APIError, 'API error')

      expect(Rails.logger).to receive(:error).with(/Riot sync failed/)

      expect {
        service.sync!
      }.to raise_error(Integrations::APIError)
    end
  end

  describe '#sync_league_of_legends' do
    let(:summoner_data) { { id: 'summoner123', name: 'TestSummoner', summonerLevel: 150 } }
    let(:ranked_data) { [{ queueType: 'RANKED_SOLO_5x5', tier: 'GOLD', rank: 'II' }] }
    let(:mastery_data) { [{ championId: 1, championLevel: 7, championPoints: 100000 }] }

    before do
      allow(api_client).to receive(:fetch_lol_summoner_by_puuid).and_return(summoner_data)
      allow(api_client).to receive(:fetch_lol_ranked_stats).and_return(ranked_data)
      allow(api_client).to receive(:fetch_lol_champion_mastery).and_return(mastery_data)
      allow(user).to receive(:update)
    end

    it 'fetches and stores LoL profile data' do
      expect(user).to receive(:update) do |args|
        lol_profile = args[:metadata][:lol_profile]
        expect(lol_profile[:summoner_name]).to eq('TestSummoner')
        expect(lol_profile[:summoner_level]).to eq(150)
        expect(lol_profile[:ranked_stats]).to be_an(Array)
        expect(lol_profile[:top_champions]).to be_an(Array)
      end

      service.send(:sync_league_of_legends)
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:fetch_lol_summoner_by_puuid)
        .and_raise(Integrations::APIError)

      expect(Rails.logger).to receive(:warn).with(/Could not sync League of Legends/)

      expect {
        service.send(:sync_league_of_legends)
      }.not_to raise_error
    end
  end

  describe '#sync_teamfight_tactics' do
    let(:tft_summoner) { { id: 'tft123', name: 'TestPlayer' } }
    let(:tft_ranked) { [{ tier: 'PLATINUM', rank: 'I' }] }

    before do
      allow(api_client).to receive(:fetch_tft_summoner_by_puuid).and_return(tft_summoner)
      allow(api_client).to receive(:fetch_tft_ranked_stats).and_return(tft_ranked)
      allow(user).to receive(:update)
    end

    it 'fetches and stores TFT profile data' do
      expect(user).to receive(:update) do |args|
        tft_profile = args[:metadata][:tft_profile]
        expect(tft_profile[:summoner_name]).to eq('TestPlayer')
        expect(tft_profile[:ranked_stats]).to be_an(Array)
      end

      service.send(:sync_teamfight_tactics)
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:fetch_tft_summoner_by_puuid)
        .and_raise(Integrations::APIError)

      expect(Rails.logger).to receive(:warn).with(/Could not sync TFT/)

      expect {
        service.send(:sync_teamfight_tactics)
      }.not_to raise_error
    end
  end

  describe '#sync_valorant' do
    let(:valorant_data) { { account: 'valorant_data' } }

    before do
      allow(api_client).to receive(:fetch_valorant_account).and_return(valorant_data)
      allow(user).to receive(:update)
    end

    it 'fetches and stores Valorant data if available' do
      expect(user).to receive(:update) do |args|
        valorant_profile = args[:metadata][:valorant_profile]
        expect(valorant_profile[:data]).to eq(valorant_data)
      end

      service.send(:sync_valorant)
    end

    it 'handles nil response' do
      allow(api_client).to receive(:fetch_valorant_account).and_return(nil)

      expect {
        service.send(:sync_valorant)
      }.not_to raise_error
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:fetch_valorant_account)
        .and_raise(Integrations::APIError)

      expect(Rails.logger).to receive(:warn).with(/Could not sync Valorant/)

      expect {
        service.send(:sync_valorant)
      }.not_to raise_error
    end
  end
end
