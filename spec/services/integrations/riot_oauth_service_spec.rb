require 'rails_helper'

RSpec.describe Integrations::RiotOauthService, type: :service do
  before do
    allow(CredentialsHelper).to receive(:riot).and_return(
      OpenStruct.new(client_id: 'riot_client_id', client_secret: 'riot_secret')
    )
  end

  describe '#initialize' do
    it 'sets provider to riot' do
      service = described_class.new
      expect(service.provider).to eq(:riot)
    end
  end

  describe '#load_config' do
    let(:service) { described_class.new }

    it 'sets authorize endpoint' do
      expect(service.config[:authorize_endpoint]).to eq('https://auth.riotgames.com/authorize')
    end

    it 'sets token endpoint' do
      expect(service.config[:token_endpoint]).to eq('https://auth.riotgames.com/token')
    end

    it 'sets revoke endpoint' do
      expect(service.config[:revoke_endpoint]).to eq('https://auth.riotgames.com/revoke')
    end

    it 'sets client credentials' do
      expect(service.config[:client_id]).to eq('riot_client_id')
      expect(service.config[:client_secret]).to eq('riot_secret')
    end

    it 'sets default scopes for Riot services' do
      expect(service.config[:default_scopes]).to include('openid')
      expect(service.config[:default_scopes]).to include('offline_access')
      expect(service.config[:default_scopes]).to include('account')
      expect(service.config[:default_scopes]).to include('summoner')
    end
  end

  describe '#token_request_headers' do
    let(:service) { described_class.new }

    it 'includes Basic Auth header' do
      headers = service.send(:token_request_headers)
      expect(headers['Authorization']).to start_with('Basic ')
    end

    it 'encodes credentials in Base64' do
      headers = service.send(:token_request_headers)
      encoded = Base64.strict_encode64('riot_client_id:riot_secret')
      expect(headers['Authorization']).to eq("Basic #{encoded}")
    end

    it 'includes Content-Type header' do
      headers = service.send(:token_request_headers)
      expect(headers['Content-Type']).to eq('application/x-www-form-urlencoded')
    end
  end

  describe '#exchange_code' do
    let(:service) { described_class.new }
    let(:token_response) do
      {
        access_token: 'riot_access_token',
        refresh_token: 'riot_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer'
      }.to_json
    end

    it 'exchanges code with Basic Auth' do
      stub_request(:post, 'https://auth.riotgames.com/token')
        .with(
          headers: { 'Authorization' => /^Basic / }
        )
        .to_return(status: 200, body: token_response)

      result = service.exchange_code('auth_code')

      expect(result[:access_token]).to eq('riot_access_token')
    end
  end

  describe '#refresh_token' do
    let(:service) { described_class.new }
    let(:refresh_response) do
      {
        access_token: 'new_riot_token',
        refresh_token: 'new_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer'
      }.to_json
    end

    it 'refreshes token with Basic Auth' do
      stub_request(:post, 'https://auth.riotgames.com/token')
        .with(
          headers: { 'Authorization' => /^Basic / },
          body: hash_including('grant_type' => 'refresh_token')
        )
        .to_return(status: 200, body: refresh_response)

      result = service.refresh_token('old_refresh_token')

      expect(result[:access_token]).to eq('new_riot_token')
    end
  end
end
