require 'rails_helper'

RSpec.describe Integrations::RiotApiClient, type: :service do
  let(:riot_account) do
    double('RiotAccount',
      access_token: 'riot_access_token',
      region: 'na1',
      ensure_valid_token!: true
    )
  end

  let(:client) { described_class.new(riot_account) }

  before do
    allow(CredentialsHelper).to receive(:riot).and_return(
      OpenStruct.new(api_key: 'riot_api_key')
    )
  end

  describe '#api_base_url' do
    it 'returns platform-specific API URL' do
      expect(client.api_base_url).to eq('https://na1.api.riotgames.com')
    end

    it 'supports different platforms' do
      allow(riot_account).to receive(:region).and_return('euw1')
      expect(client.api_base_url).to eq('https://euw1.api.riotgames.com')
    end

    it 'defaults to na1' do
      allow(riot_account).to receive(:region).and_return(nil)
      expect(client.api_base_url).to eq('https://na1.api.riotgames.com')
    end
  end

  describe '#regional_api_base_url' do
    it 'returns regional URL for NA platforms' do
      expect(client.regional_api_base_url).to eq('https://americas.api.riotgames.com')
    end

    it 'returns europe for EU platforms' do
      allow(riot_account).to receive(:region).and_return('euw1')
      expect(client.regional_api_base_url).to eq('https://europe.api.riotgames.com')
    end

    it 'returns asia for KR platform' do
      allow(riot_account).to receive(:region).and_return('kr')
      expect(client.regional_api_base_url).to eq('https://asia.api.riotgames.com')
    end

    it 'returns sea for Oceania platform' do
      allow(riot_account).to receive(:region).and_return('oc1')
      expect(client.regional_api_base_url).to eq('https://sea.api.riotgames.com')
    end
  end

  describe '#fetch_account_info' do
    let(:account_response) do
      {
        puuid: 'test_puuid',
        gameName: 'TestPlayer',
        tagLine: '1234'
      }.to_json
    end

    it 'fetches account info from RSO API' do
      stub_request(:get, 'https://americas.api.riotgames.com/riot/account/v1/accounts/me')
        .with(headers: { 'Authorization' => 'Bearer riot_access_token' })
        .to_return(status: 200, body: account_response)

      result = client.fetch_account_info

      expect(result[:puuid]).to eq('test_puuid')
      expect(result[:gameName]).to eq('TestPlayer')
    end
  end

  describe 'League of Legends methods' do
    describe '#fetch_lol_summoner_by_puuid' do
      let(:summoner_response) do
        {
          id: 'summoner_id',
          accountId: 'account_id',
          puuid: 'test_puuid',
          name: 'TestSummoner',
          summonerLevel: 150
        }.to_json
      end

      it 'fetches summoner by PUUID' do
        stub_request(:get, 'https://na1.api.riotgames.com/lol/summoner/v4/summoners/by-puuid/test_puuid')
          .to_return(status: 200, body: summoner_response)

        result = client.fetch_lol_summoner_by_puuid('test_puuid')

        expect(result[:name]).to eq('TestSummoner')
        expect(result[:summonerLevel]).to eq(150)
      end
    end

    describe '#fetch_lol_ranked_stats' do
      let(:ranked_response) do
        [
          {
            queueType: 'RANKED_SOLO_5x5',
            tier: 'GOLD',
            rank: 'II',
            leaguePoints: 75
          }
        ].to_json
      end

      it 'fetches ranked stats' do
        stub_request(:get, 'https://na1.api.riotgames.com/lol/league/v4/entries/by-summoner/summoner123')
          .to_return(status: 200, body: ranked_response)

        result = client.fetch_lol_ranked_stats('summoner123')

        expect(result.first[:tier]).to eq('GOLD')
      end
    end

    describe '#fetch_lol_champion_mastery' do
      let(:mastery_response) do
        [
          { championId: 1, championLevel: 7, championPoints: 100000 }
        ].to_json
      end

      it 'fetches champion mastery' do
        stub_request(:get, 'https://na1.api.riotgames.com/lol/champion-mastery/v4/champion-masteries/by-puuid/test_puuid')
          .to_return(status: 200, body: mastery_response)

        result = client.fetch_lol_champion_mastery('test_puuid')

        expect(result.first[:championLevel]).to eq(7)
      end
    end
  end

  describe 'Teamfight Tactics methods' do
    describe '#fetch_tft_summoner_by_puuid' do
      let(:summoner_response) do
        {
          id: 'tft_summoner_id',
          puuid: 'test_puuid',
          name: 'TestPlayer'
        }.to_json
      end

      it 'fetches TFT summoner' do
        stub_request(:get, 'https://na1.api.riotgames.com/tft/summoner/v1/summoners/by-puuid/test_puuid')
          .to_return(status: 200, body: summoner_response)

        result = client.fetch_tft_summoner_by_puuid('test_puuid')

        expect(result[:name]).to eq('TestPlayer')
      end
    end
  end

  describe '#default_headers' do
    it 'includes Bearer token' do
      headers = client.send(:default_headers)
      expect(headers['Authorization']).to eq('Bearer riot_access_token')
    end

    it 'includes X-Riot-Token API key' do
      headers = client.send(:default_headers)
      expect(headers['X-Riot-Token']).to eq('riot_api_key')
    end

    it 'raises error if API key is missing' do
      allow(CredentialsHelper).to receive(:riot)
        .and_raise(CredentialsHelper::MissingCredentialsError)

      expect {
        client.send(:default_headers)
      }.to raise_error(Integrations::APIError, /Missing Riot API key/)
    end
  end

  describe 'Valorant methods' do
    describe '#fetch_valorant_account' do
      it 'returns nil on ForbiddenError' do
        stub_request(:get, %r{api.riotgames.com/val/account})
          .to_return(status: 403, body: 'Forbidden')

        expect(Rails.logger).to receive(:warn).with(/Valorant API access not available/)

        result = client.fetch_valorant_account('test_puuid')
        expect(result).to be_nil
      end
    end
  end
end
