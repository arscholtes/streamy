require 'rails_helper'

RSpec.describe Integrations::SteamApiClient, type: :service do
  let(:steam_account) { create(:steam_account, steam_id: '76561198000000000') }
  let(:client) { described_class.new(steam_account) }

  before do
    # Mock the API key
    allow(ENV).to receive(:[]).with('STEAM_API_KEY').and_return('test_api_key')
  end

  describe '#initialize' do
    it 'sets the steam_id from the account' do
      expect(client.instance_variable_get(:@steam_id)).to eq('76561198000000000')
    end

    it 'raises an error if no API key is configured' do
      allow(ENV).to receive(:[]).with('STEAM_API_KEY').and_return(nil)
      allow(Rails.application.credentials).to receive(:dig).with(:steam, :api_key).and_return(nil)

      expect {
        described_class.new(steam_account)
      }.to raise_error('STEAM_API_KEY not configured')
    end
  end

  describe '#get_owned_games' do
    let(:response_body) do
      {
        'response' => {
          'game_count' => 2,
          'games' => [
            {
              'appid' => 570,
              'name' => 'Dota 2',
              'playtime_forever' => 1000,
              'img_icon_url' => 'abc123'
            },
            {
              'appid' => 730,
              'name' => 'Counter-Strike 2',
              'playtime_forever' => 500,
              'img_icon_url' => 'def456'
            }
          ]
        }
      }.to_json
    end

    it 'fetches owned games successfully' do
      stub_request(:get, /api\.steampowered\.com\/IPlayerService\/GetOwnedGames/)
        .to_return(status: 200, body: response_body)

      result = client.get_owned_games
      expect(result['response']['games'].count).to eq(2)
      expect(result['response']['games'].first['name']).to eq('Dota 2')
    end

    it 'includes API key in request' do
      stub_request(:get, /api\.steampowered\.com\/IPlayerService\/GetOwnedGames/)
        .with(query: hash_including('key' => 'test_api_key'))
        .to_return(status: 200, body: response_body)

      client.get_owned_games
    end
  end

  describe '#get_recent_games' do
    let(:response_body) do
      {
        'response' => {
          'total_count' => 1,
          'games' => [
            {
              'appid' => 570,
              'name' => 'Dota 2',
              'playtime_2weeks' => 120,
              'playtime_forever' => 1000
            }
          ]
        }
      }.to_json
    end

    it 'fetches recently played games' do
      stub_request(:get, /api\.steampowered\.com\/IPlayerService\/GetRecentlyPlayedGames/)
        .to_return(status: 200, body: response_body)

      result = client.get_recently_played_games
      expect(result['response']['games'].count).to eq(1)
    end
  end

  describe '#get_player_achievements' do
    let(:success_response) do
      {
        'playerstats' => {
          'steamID' => '76561198000000000',
          'gameName' => 'Dota 2',
          'achievements' => [
            { 'apiname' => 'FIRST_BLOOD', 'achieved' => 1 }
          ]
        }
      }.to_json
    end

    it 'fetches achievements successfully' do
      stub_request(:get, /api\.steampowered\.com\/ISteamUserStats\/GetPlayerAchievements/)
        .to_return(status: 200, body: success_response)

      result = client.get_player_achievements(570)
      expect(result['playerstats']['achievements'].count).to eq(1)
    end

    it 'returns empty achievements for games without them' do
      stub_request(:get, /api\.steampowered\.com\/ISteamUserStats\/GetPlayerAchievements/)
        .to_return(status: 400, body: 'Game does not have achievements')

      result = client.get_player_achievements(999)
      expect(result[:playerstats][:achievements]).to eq([])
    end
  end

  describe 'error handling' do
    it 'raises authentication error for 401' do
      stub_request(:get, /api\.steampowered\.com/)
        .to_return(status: 401, body: 'Unauthorized')

      expect {
        client.get_owned_games
      }.to raise_error(Integrations::AuthenticationError, /Invalid API key/)
    end

    it 'raises rate limit error for 429' do
      stub_request(:get, /api\.steampowered\.com/)
        .to_return(status: 429, body: 'Too many requests')

      expect {
        client.get_owned_games
      }.to raise_error(Integrations::RateLimitError)
    end

    it 'raises API error for 500' do
      stub_request(:get, /api\.steampowered\.com/)
        .to_return(status: 500, body: 'Internal server error')

      expect {
        client.get_owned_games
      }.to raise_error(Integrations::APIError)
    end
  end
end
