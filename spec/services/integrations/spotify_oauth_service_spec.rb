require 'rails_helper'

RSpec.describe Integrations::SpotifyOauthService, type: :service do
  before do
    allow(CredentialsHelper).to receive(:spotify).and_return(
      OpenStruct.new(client_id: 'spotify_client_id', client_secret: 'spotify_secret')
    )
  end

  describe '#initialize' do
    it 'sets provider to spotify' do
      service = described_class.new
      expect(service.provider).to eq(:spotify)
    end
  end

  describe '#load_config' do
    let(:service) { described_class.new }

    it 'sets authorize endpoint' do
      expect(service.config[:authorize_endpoint]).to eq('https://accounts.spotify.com/authorize')
    end

    it 'sets token endpoint' do
      expect(service.config[:token_endpoint]).to eq('https://accounts.spotify.com/api/token')
    end

    it 'sets client credentials' do
      expect(service.config[:client_id]).to eq('spotify_client_id')
      expect(service.config[:client_secret]).to eq('spotify_secret')
    end

    it 'sets default scopes for Spotify' do
      expect(service.config[:default_scopes]).to include('user-read-private')
      expect(service.config[:default_scopes]).to include('user-read-email')
      expect(service.config[:default_scopes]).to include('user-read-currently-playing')
      expect(service.config[:default_scopes]).to include('user-read-recently-played')
      expect(service.config[:default_scopes]).to include('user-top-read')
      expect(service.config[:default_scopes]).to include('user-read-playback-state')
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
      encoded = Base64.strict_encode64('spotify_client_id:spotify_secret')
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
        access_token: 'spotify_access_token',
        refresh_token: 'spotify_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer'
      }.to_json
    end

    it 'exchanges code with Basic Auth' do
      stub_request(:post, 'https://accounts.spotify.com/api/token')
        .with(headers: { 'Authorization' => /^Basic / })
        .to_return(status: 200, body: token_response)

      result = service.exchange_code('auth_code')

      expect(result[:access_token]).to eq('spotify_access_token')
    end
  end
end
