require 'rails_helper'

RSpec.describe Integrations::BattlenetApiClient, type: :service do
  let(:battlenet_account) do
    double('BattlenetAccount',
      access_token: 'battlenet_access_token',
      region: 'us',
      ensure_valid_token!: true
    )
  end

  let(:client) { described_class.new(battlenet_account) }

  describe '#api_base_url' do
    it 'returns US API URL for us region' do
      expect(client.api_base_url).to eq('https://us.api.blizzard.com')
    end

    it 'returns EU API URL for eu region' do
      allow(battlenet_account).to receive(:region).and_return('eu')
      expect(client.api_base_url).to eq('https://eu.api.blizzard.com')
    end

    it 'returns KR API URL for kr region' do
      allow(battlenet_account).to receive(:region).and_return('kr')
      expect(client.api_base_url).to eq('https://kr.api.blizzard.com')
    end

    it 'returns TW API URL for tw region' do
      allow(battlenet_account).to receive(:region).and_return('tw')
      expect(client.api_base_url).to eq('https://tw.api.blizzard.com')
    end

    it 'returns CN API URL for cn region' do
      allow(battlenet_account).to receive(:region).and_return('cn')
      expect(client.api_base_url).to eq('https://gateway.battlenet.com.cn')
    end

    it 'defaults to US API URL for unknown region' do
      allow(battlenet_account).to receive(:region).and_return('unknown')
      expect(client.api_base_url).to eq('https://us.api.blizzard.com')
    end

    it 'defaults to US API URL when region is nil' do
      allow(battlenet_account).to receive(:region).and_return(nil)
      expect(client.api_base_url).to eq('https://us.api.blizzard.com')
    end
  end

  describe '#oauth_base_url' do
    it 'returns standard OAuth URL for non-CN regions' do
      expect(client.send(:oauth_base_url)).to eq('https://oauth.battle.net')
    end

    it 'returns CN OAuth URL for cn region' do
      allow(battlenet_account).to receive(:region).and_return('cn')
      expect(client.send(:oauth_base_url)).to eq('https://oauth.battlenet.com.cn')
    end
  end

  describe '#fetch_user_profile' do
    let(:profile_response) do
      {
        sub: '12345',
        id: 67890,
        battletag: 'TestUser#1234'
      }.to_json
    end

    it 'fetches user profile from OAuth userinfo endpoint' do
      stub_request(:get, 'https://oauth.battle.net/oauth/userinfo')
        .with(headers: { 'Authorization' => 'Bearer battlenet_access_token' })
        .to_return(status: 200, body: profile_response)

      result = client.fetch_user_profile

      expect(result[:battletag]).to eq('TestUser#1234')
      expect(result[:id]).to eq(67890)
      expect(result[:sub]).to eq('12345')
    end
  end

  describe '#fetch_account_info' do
    let(:account_response) do
      {
        sub: '12345',
        id: 67890,
        battletag: 'TestUser#1234'
      }.to_json
    end

    it 'fetches account information' do
      stub_request(:get, 'https://oauth.battle.net/oauth/userinfo')
        .to_return(status: 200, body: account_response)

      result = client.fetch_account_info

      expect(result[:battletag]).to eq('TestUser#1234')
      expect(result[:id]).to eq(67890)
      expect(result[:sub]).to eq('12345')
    end
  end

  describe 'World of Warcraft methods' do
    describe '#fetch_wow_profile' do
      let(:wow_response) do
        {
          wow_accounts: [
            {
              id: 123,
              characters: [
                { name: 'Testchar', level: 70 }
              ]
            }
          ]
        }.to_json
      end

      it 'fetches WoW profile data' do
        stub_request(:get, 'https://us.api.blizzard.com/profile/user/wow')
          .with(query: hash_including('namespace' => 'profile-us'))
          .to_return(status: 200, body: wow_response)

        result = client.fetch_wow_profile

        expect(result[:wow_accounts]).to be_an(Array)
        expect(result[:wow_accounts].first[:id]).to eq(123)
      end
    end

    describe '#fetch_wow_character' do
      let(:character_response) do
        {
          name: 'Testchar',
          level: 70,
          realm: { name: 'TestRealm' }
        }.to_json
      end

      it 'fetches WoW character data' do
        stub_request(:get, 'https://us.api.blizzard.com/profile/wow/character/test-realm/testchar')
          .with(query: hash_including('namespace' => 'profile-us', 'locale' => 'en_US'))
          .to_return(status: 200, body: character_response)

        result = client.fetch_wow_character('test-realm', 'TestChar')

        expect(result[:name]).to eq('Testchar')
        expect(result[:level]).to eq(70)
      end

      it 'converts character name to lowercase' do
        stub_request(:get, 'https://us.api.blizzard.com/profile/wow/character/test-realm/uppercase')
          .to_return(status: 200, body: character_response)

        client.fetch_wow_character('test-realm', 'UPPERCASE')
      end
    end
  end

  describe 'Diablo 3 methods' do
    describe '#fetch_diablo_profile' do
      let(:diablo_response) do
        {
          heroes: [
            { name: 'TestHero', class: 'wizard', level: 70 }
          ]
        }.to_json
      end

      it 'fetches Diablo 3 profile data' do
        stub_request(:get, 'https://us.api.blizzard.com/d3/profile/user/index')
          .with(query: hash_including('locale' => 'en_US'))
          .to_return(status: 200, body: diablo_response)

        result = client.fetch_diablo_profile

        expect(result[:heroes]).to be_an(Array)
      end
    end
  end

  describe 'StarCraft 2 methods' do
    describe '#fetch_sc2_profile' do
      let(:sc2_response) do
        {
          summary: [
            { id: '123', displayName: 'TestPlayer' }
          ]
        }.to_json
      end

      it 'fetches StarCraft 2 profile data' do
        stub_request(:get, 'https://us.api.blizzard.com/sc2/profile/user')
          .to_return(status: 200, body: sc2_response)

        result = client.fetch_sc2_profile

        expect(result[:summary]).to be_an(Array)
      end
    end
  end

  describe 'Overwatch methods' do
    describe '#fetch_overwatch_summary' do
      it 'returns empty hash (limited API support)' do
        result = client.fetch_overwatch_summary
        expect(result).to eq({})
      end
    end
  end

  describe 'error handling' do
    it 'raises UnauthorizedError for 401' do
      stub_request(:get, 'https://us.api.blizzard.com/profile/user/wow')
        .to_return(status: 401, body: 'Unauthorized')

      expect {
        client.fetch_wow_profile
      }.to raise_error(Integrations::UnauthorizedError)
    end

    it 'raises NotFoundError for 404' do
      stub_request(:get, 'https://us.api.blizzard.com/profile/user/wow')
        .to_return(status: 404, body: 'Not Found')

      expect {
        client.fetch_wow_profile
      }.to raise_error(Integrations::NotFoundError)
    end
  end
end
