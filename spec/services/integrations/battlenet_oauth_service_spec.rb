require 'rails_helper'

RSpec.describe Integrations::BattlenetOauthService, type: :service do
  before do
    allow(CredentialsHelper).to receive(:battlenet).and_return(
      OpenStruct.new(client_id: 'battlenet_client_id', client_secret: 'battlenet_secret')
    )
  end

  describe '#initialize' do
    it 'sets provider to battlenet' do
      service = described_class.new
      expect(service.provider).to eq(:battlenet)
    end

    it 'defaults to US region' do
      service = described_class.new
      expect(service.instance_variable_get(:@region)).to eq(:us)
    end

    it 'accepts custom region' do
      service = described_class.new(region: :eu)
      expect(service.instance_variable_get(:@region)).to eq(:eu)
    end
  end

  describe 'region support' do
    it 'supports US region' do
      service = described_class.new(region: :us)
      expect(service.config[:authorize_endpoint]).to include('oauth.battle.net')
    end

    it 'supports EU region' do
      service = described_class.new(region: :eu)
      expect(service.config[:authorize_endpoint]).to include('oauth.battle.net')
    end

    it 'supports KR region' do
      service = described_class.new(region: :kr)
      expect(service.config[:authorize_endpoint]).to include('oauth.battle.net')
    end

    it 'supports TW region' do
      service = described_class.new(region: :tw)
      expect(service.config[:authorize_endpoint]).to include('oauth.battle.net')
    end

    it 'supports CN region with different domain' do
      service = described_class.new(region: :cn)
      expect(service.config[:authorize_endpoint]).to include('oauth.battlenet.com.cn')
    end
  end

  describe '#load_config' do
    let(:service) { described_class.new(region: :us) }

    it 'sets authorize endpoint' do
      expect(service.config[:authorize_endpoint]).to eq('https://oauth.battle.net/authorize')
    end

    it 'sets token endpoint' do
      expect(service.config[:token_endpoint]).to eq('https://oauth.battle.net/token')
    end

    it 'sets client credentials' do
      expect(service.config[:client_id]).to eq('battlenet_client_id')
      expect(service.config[:client_secret]).to eq('battlenet_secret')
    end

    it 'sets default scopes for Battle.net games' do
      expect(service.config[:default_scopes]).to include('wow.profile')
      expect(service.config[:default_scopes]).to include('sc2.profile')
      expect(service.config[:default_scopes]).to include('d3.profile')
      expect(service.config[:default_scopes]).to include('openid')
    end
  end

  describe '#api_base_url' do
    it 'returns US API URL for us region' do
      service = described_class.new(region: :us)
      expect(service.send(:api_base_url)).to eq('https://us.api.blizzard.com')
    end

    it 'returns EU API URL for eu region' do
      service = described_class.new(region: :eu)
      expect(service.send(:api_base_url)).to eq('https://eu.api.blizzard.com')
    end

    it 'returns KR API URL for kr region' do
      service = described_class.new(region: :kr)
      expect(service.send(:api_base_url)).to eq('https://kr.api.blizzard.com')
    end

    it 'returns TW API URL for tw region' do
      service = described_class.new(region: :tw)
      expect(service.send(:api_base_url)).to eq('https://tw.api.blizzard.com')
    end

    it 'returns CN API URL for cn region' do
      service = described_class.new(region: :cn)
      expect(service.send(:api_base_url)).to eq('https://gateway.battlenet.com.cn')
    end

    it 'defaults to US API URL for unknown region' do
      service = described_class.new(region: :unknown)
      expect(service.send(:api_base_url)).to eq('https://us.api.blizzard.com')
    end
  end

  describe '#authorization_url' do
    let(:service) { described_class.new(region: :us) }

    it 'generates authorization URL with Battle.net scopes' do
      url = service.authorization_url
      params = CGI.parse(URI.parse(url).query)

      expect(params['scope'].first).to include('wow.profile')
      expect(params['scope'].first).to include('sc2.profile')
      expect(params['scope'].first).to include('d3.profile')
      expect(params['scope'].first).to include('openid')
    end
  end

  describe '#exchange_code' do
    let(:service) { described_class.new(region: :us) }
    let(:token_response) do
      {
        access_token: 'battlenet_access_token',
        refresh_token: 'battlenet_refresh_token',
        expires_in: 86400,
        token_type: 'Bearer'
      }.to_json
    end

    it 'exchanges code for access token' do
      stub_request(:post, 'https://oauth.battle.net/token')
        .to_return(status: 200, body: token_response)

      result = service.exchange_code('auth_code')

      expect(result[:access_token]).to eq('battlenet_access_token')
      expect(result[:refresh_token]).to eq('battlenet_refresh_token')
    end
  end

  describe '#refresh_token' do
    let(:service) { described_class.new(region: :us) }
    let(:refresh_response) do
      {
        access_token: 'new_battlenet_token',
        expires_in: 86400,
        token_type: 'Bearer'
      }.to_json
    end

    it 'refreshes access token' do
      stub_request(:post, 'https://oauth.battle.net/token')
        .with(body: hash_including('grant_type' => 'refresh_token'))
        .to_return(status: 200, body: refresh_response)

      result = service.refresh_token('old_refresh_token')

      expect(result[:access_token]).to eq('new_battlenet_token')
    end
  end
end
