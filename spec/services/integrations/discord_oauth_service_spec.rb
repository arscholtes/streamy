require 'rails_helper'

RSpec.describe Integrations::DiscordOauthService, type: :service do
  before do
    allow(CredentialsHelper).to receive(:discord).and_return(
      OpenStruct.new(client_id: 'discord_client_id', client_secret: 'discord_secret')
    )
  end

  describe '#initialize' do
    it 'sets provider to discord' do
      service = described_class.new
      expect(service.provider).to eq(:discord)
    end
  end

  describe '#load_config' do
    let(:service) { described_class.new }

    it 'sets authorize endpoint' do
      expect(service.config[:authorize_endpoint]).to eq('https://discord.com/api/oauth2/authorize')
    end

    it 'sets token endpoint' do
      expect(service.config[:token_endpoint]).to eq('https://discord.com/api/v10/oauth2/token')
    end

    it 'sets client credentials' do
      expect(service.config[:client_id]).to eq('discord_client_id')
      expect(service.config[:client_secret]).to eq('discord_secret')
    end

    it 'sets default scopes' do
      expect(service.config[:default_scopes]).to include('identify')
      expect(service.config[:default_scopes]).to include('email')
      expect(service.config[:default_scopes]).to include('guilds')
    end
  end

  describe '#exchange_code' do
    let(:service) { described_class.new }
    let(:token_response) do
      {
        access_token: 'discord_access_token',
        refresh_token: 'discord_refresh_token',
        expires_in: 604800,
        token_type: 'Bearer'
      }.to_json
    end

    it 'exchanges authorization code for tokens' do
      stub_request(:post, 'https://discord.com/api/v10/oauth2/token')
        .to_return(status: 200, body: token_response)

      result = service.exchange_code('auth_code')

      expect(result[:access_token]).to eq('discord_access_token')
      expect(result[:refresh_token]).to eq('discord_refresh_token')
    end
  end
end
