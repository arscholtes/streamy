require 'rails_helper'

RSpec.describe Integrations::YoutubeOauthService, type: :service do
  before do
    allow(CredentialsHelper).to receive(:youtube).and_return(
      OpenStruct.new(client_id: 'youtube_client_id', client_secret: 'youtube_secret')
    )
  end

  describe '#initialize' do
    it 'sets provider to youtube' do
      service = described_class.new
      expect(service.provider).to eq(:youtube)
    end
  end

  describe '#load_config' do
    let(:service) { described_class.new }

    it 'sets authorize endpoint' do
      expect(service.config[:authorize_endpoint]).to eq('https://accounts.google.com/o/oauth2/v2/auth')
    end

    it 'sets token endpoint' do
      expect(service.config[:token_endpoint]).to eq('https://oauth2.googleapis.com/token')
    end

    it 'sets revoke endpoint' do
      expect(service.config[:revoke_endpoint]).to eq('https://oauth2.googleapis.com/revoke')
    end

    it 'sets client credentials' do
      expect(service.config[:client_id]).to eq('youtube_client_id')
      expect(service.config[:client_secret]).to eq('youtube_secret')
    end

    it 'sets default scopes' do
      expect(service.config[:default_scopes]).to include('https://www.googleapis.com/auth/youtube.readonly')
      expect(service.config[:default_scopes]).to include('https://www.googleapis.com/auth/youtube.upload')
      expect(service.config[:default_scopes]).to include('https://www.googleapis.com/auth/userinfo.profile')
    end
  end

  describe '#authorization_url' do
    let(:service) { described_class.new }

    before do
      # Set default URL options for tests
      Rails.application.routes.default_url_options[:host] = 'example.com'
    end

    it 'includes access_type=offline and prompt=consent' do
      url = service.send(:authorization_url)
      expect(url).to include('access_type=offline')
      expect(url).to include('prompt=consent')
    end

    it 'includes required OAuth parameters' do
      url = service.send(:authorization_url)
      expect(url).to include('client_id=youtube_client_id')
      expect(url).to include('response_type=code')
      expect(url).to include('scope=')
    end
  end

  describe '#exchange_code' do
    let(:service) { described_class.new }
    let(:token_response) do
      {
        access_token: 'youtube_access_token',
        refresh_token: 'youtube_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer',
        scope: 'https://www.googleapis.com/auth/youtube.readonly'
      }.to_json
    end

    before do
      Rails.application.routes.default_url_options[:host] = 'example.com'
    end

    it 'exchanges authorization code for tokens' do
      stub_request(:post, 'https://oauth2.googleapis.com/token')
        .to_return(status: 200, body: token_response)

      result = service.exchange_code('auth_code')

      expect(result[:access_token]).to eq('youtube_access_token')
      expect(result[:refresh_token]).to eq('youtube_refresh_token')
      expect(result[:expires_in]).to eq(3600)
    end
  end
end
