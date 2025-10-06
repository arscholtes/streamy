require 'rails_helper'

RSpec.describe Integrations::SteamOauthService, type: :service do
  let(:return_url) { 'https://myapp.com/integrations/steam/callback' }
  let(:service) { described_class.new(return_url) }

  before do
    allow(CredentialsHelper).to receive(:steam).and_return(
      OpenStruct.new(api_key: 'steam_api_key')
    )
  end

  describe '#initialize' do
    it 'sets the API key from credentials' do
      expect(service.instance_variable_get(:@api_key)).to eq('steam_api_key')
    end

    it 'sets the return URL' do
      expect(service.instance_variable_get(:@return_url)).to eq(return_url)
    end

    it 'raises error when API key is missing' do
      allow(CredentialsHelper).to receive(:steam)
        .and_raise(CredentialsHelper::MissingCredentialsError)

      expect {
        described_class.new(return_url)
      }.to raise_error(Integrations::AuthenticationError, /Missing Steam API key/)
    end
  end

  describe '#authorize_url' do
    it 'generates OpenID login URL' do
      url = service.authorize_url
      expect(url).to start_with('https://steamcommunity.com/openid/login')
    end

    it 'includes OpenID namespace' do
      url = service.authorize_url
      expect(url).to include('openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0')
    end

    it 'includes return_to parameter' do
      url = service.authorize_url
      expect(url).to include(CGI.escape(return_url))
    end

    it 'includes realm parameter' do
      url = service.authorize_url
      expect(url).to include('openid.realm=https%3A%2F%2Fmyapp.com')
    end

    it 'includes identity selectors' do
      url = service.authorize_url
      expect(url).to include('openid.identity')
      expect(url).to include('openid.claimed_id')
    end

    it 'raises error if return URL not configured' do
      service = described_class.new
      expect {
        service.authorize_url
      }.to raise_error('Return URL not configured')
    end
  end

  describe '#verify_and_extract_steam_id' do
    let(:openid_params) do
      {
        'openid.mode' => 'id_res',
        'openid.claimed_id' => 'https://steamcommunity.com/openid/id/76561197960435530',
        'openid.identity' => 'https://steamcommunity.com/openid/id/76561197960435530',
        'openid.signed' => 'signed',
        'openid.sig' => 'signature'
      }
    end

    it 'verifies OpenID signature and extracts Steam ID' do
      stub_request(:get, 'https://steamcommunity.com/openid/login')
        .with(query: hash_including('openid.mode' => 'check_authentication'))
        .to_return(status: 200, body: "is_valid:true\n")

      steam_id = service.verify_and_extract_steam_id(openid_params)

      expect(steam_id).to eq('76561197960435530')
    end

    it 'raises AuthenticationError for invalid signature' do
      stub_request(:get, 'https://steamcommunity.com/openid/login')
        .to_return(status: 200, body: "is_valid:false\n")

      expect {
        service.verify_and_extract_steam_id(openid_params)
      }.to raise_error(Integrations::AuthenticationError, /Invalid OpenID signature/)
    end

    it 'handles ActionController::Parameters' do
      stub_request(:get, 'https://steamcommunity.com/openid/login')
        .to_return(status: 200, body: "is_valid:true\n")

      # Simulate Rails params object
      params_object = double('ActionController::Parameters')
      allow(params_object).to receive(:to_unsafe_h).and_return(openid_params)
      allow(params_object).to receive(:[]).with('openid.claimed_id').and_return(openid_params['openid.claimed_id'])

      steam_id = service.verify_and_extract_steam_id(params_object)

      expect(steam_id).to eq('76561197960435530')
    end
  end

  describe '#fetch_user_data' do
    let(:steam_id) { '76561197960435530' }
    let(:user_response) do
      {
        'response' => {
          'players' => [
            {
              'steamid' => steam_id,
              'personaname' => 'TestPlayer',
              'profileurl' => 'https://steamcommunity.com/id/test/',
              'avatarfull' => 'https://avatar.url',
              'realname' => 'Test User',
              'loccountrycode' => 'US',
              'locstatecode' => 'CA',
              'communityvisibilitystate' => 3,
              'timecreated' => 1234567890,
              'lastlogoff' => 1234567900
            }
          ]
        }
      }.to_json
    end

    it 'fetches user data from Steam API' do
      stub_request(:get, 'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/')
        .with(query: { key: 'steam_api_key', steamids: steam_id })
        .to_return(status: 200, body: user_response)

      result = service.fetch_user_data(steam_id)

      expect(result[:steam_id]).to eq(steam_id)
      expect(result[:persona_name]).to eq('TestPlayer')
      expect(result[:profile_url]).to eq('https://steamcommunity.com/id/test/')
      expect(result[:avatar_url]).to eq('https://avatar.url')
    end

    it 'raises APIError when request fails' do
      stub_request(:get, 'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/')
        .to_return(status: 500, body: 'Error')

      expect {
        service.fetch_user_data(steam_id)
      }.to raise_error(Integrations::APIError, /Failed to fetch Steam user data/)
    end

    it 'raises APIError when no players returned' do
      stub_request(:get, 'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/')
        .to_return(status: 200, body: { 'response' => { 'players' => [] } }.to_json)

      expect {
        service.fetch_user_data(steam_id)
      }.to raise_error(Integrations::APIError)
    end
  end

  describe '#generate_pseudo_tokens' do
    let(:steam_id) { '76561197960435530' }

    it 'generates pseudo access token' do
      result = service.generate_pseudo_tokens(steam_id)

      expect(result[:access_token]).to start_with("steam_#{steam_id}_")
      expect(result[:access_token].length).to be > 50
    end

    it 'sets refresh_token to nil' do
      result = service.generate_pseudo_tokens(steam_id)
      expect(result[:refresh_token]).to be_nil
    end

    it 'sets expires_at to 1 year from now' do
      result = service.generate_pseudo_tokens(steam_id)
      expect(result[:expires_at]).to be_within(1.minute).of(1.year.from_now)
    end

    it 'generates unique tokens each time' do
      token1 = service.generate_pseudo_tokens(steam_id)[:access_token]
      token2 = service.generate_pseudo_tokens(steam_id)[:access_token]

      expect(token1).not_to eq(token2)
    end
  end

  describe 'realm extraction' do
    it 'extracts realm from return URL' do
      realm = service.send(:realm)
      expect(realm).to eq('https://myapp.com')
    end

    it 'includes port if not standard' do
      custom_service = described_class.new('http://localhost:3000/callback')
      realm = custom_service.send(:realm)
      expect(realm).to eq('http://localhost:3000')
    end

    it 'excludes standard HTTP port 80' do
      custom_service = described_class.new('http://example.com:80/callback')
      realm = custom_service.send(:realm)
      expect(realm).to eq('http://example.com')
    end

    it 'excludes standard HTTPS port 443' do
      custom_service = described_class.new('https://example.com:443/callback')
      realm = custom_service.send(:realm)
      expect(realm).to eq('https://example.com')
    end
  end
end
