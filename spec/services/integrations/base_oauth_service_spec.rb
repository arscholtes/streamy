require 'rails_helper'

RSpec.describe Integrations::BaseOauthService, type: :service do
  # Create a test subclass for testing the base class
  let(:test_service_class) do
    Class.new(Integrations::BaseOauthService) do
      def load_config
        {
          authorize_endpoint: 'https://example.com/oauth/authorize',
          token_endpoint: 'https://example.com/oauth/token',
          revoke_endpoint: 'https://example.com/oauth/revoke',
          client_id: 'test_client_id',
          client_secret: 'test_client_secret',
          callback_url: 'https://myapp.com/callback',
          default_scopes: ['read', 'write']
        }
      end
    end
  end

  let(:service) { test_service_class.new(:test_provider) }

  before do
    # Stub CredentialsHelper to avoid credential errors
    allow(CredentialsHelper).to receive(:integration).and_return(
      OpenStruct.new(client_id: 'test_client_id', client_secret: 'test_client_secret')
    )
  end

  describe '#initialize' do
    it 'sets the provider' do
      expect(service.provider).to eq(:test_provider)
    end

    it 'loads the config' do
      expect(service.config).to be_a(Hash)
      expect(service.config[:client_id]).to eq('test_client_id')
    end

    it 'accepts optional region parameter' do
      service = test_service_class.new(:test_provider, region: :us)
      expect(service.instance_variable_get(:@region)).to eq(:us)
    end
  end

  describe '#authorization_url' do
    it 'generates OAuth authorization URL with required parameters' do
      url = service.authorization_url
      uri = URI.parse(url)

      expect(uri.to_s).to start_with('https://example.com/oauth/authorize')

      params = CGI.parse(uri.query)
      expect(params['client_id']).to eq(['test_client_id'])
      expect(params['redirect_uri']).to eq(['https://myapp.com/callback'])
      expect(params['response_type']).to eq(['code'])
    end

    it 'includes state parameter' do
      url = service.authorization_url(state: 'custom_state')
      params = CGI.parse(URI.parse(url).query)

      expect(params['state']).to eq(['custom_state'])
    end

    it 'generates state token if not provided' do
      url = service.authorization_url
      params = CGI.parse(URI.parse(url).query)

      expect(params['state'].first).not_to be_nil
      expect(params['state'].first.length).to be > 20
    end

    it 'includes default scopes' do
      url = service.authorization_url
      params = CGI.parse(URI.parse(url).query)

      expect(params['scope']).to eq(['read write'])
    end

    it 'accepts custom scopes' do
      url = service.authorization_url(scopes: ['custom', 'scopes'])
      params = CGI.parse(URI.parse(url).query)

      expect(params['scope']).to eq(['custom scopes'])
    end

    it 'accepts scopes as string' do
      url = service.authorization_url(scopes: 'custom scopes')
      params = CGI.parse(URI.parse(url).query)

      expect(params['scope']).to eq(['custom scopes'])
    end
  end

  describe '#exchange_code' do
    let(:token_response) do
      {
        access_token: 'new_access_token',
        refresh_token: 'new_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer',
        scope: 'read write'
      }.to_json
    end

    it 'exchanges authorization code for tokens' do
      stub_request(:post, 'https://example.com/oauth/token')
        .with(
          body: hash_including(
            'grant_type' => 'authorization_code',
            'code' => 'auth_code_123',
            'client_id' => 'test_client_id',
            'client_secret' => 'test_client_secret'
          )
        )
        .to_return(status: 200, body: token_response)

      result = service.exchange_code('auth_code_123')

      expect(result[:access_token]).to eq('new_access_token')
      expect(result[:refresh_token]).to eq('new_refresh_token')
      expect(result[:expires_in]).to eq(3600)
      expect(result[:token_type]).to eq('Bearer')
      expect(result[:scope]).to eq('read write')
    end

    it 'includes redirect_uri in request' do
      stub_request(:post, 'https://example.com/oauth/token')
        .with(
          body: hash_including('redirect_uri' => 'https://myapp.com/callback')
        )
        .to_return(status: 200, body: token_response)

      service.exchange_code('auth_code_123')
    end

    it 'raises OAuthError on failure' do
      stub_request(:post, 'https://example.com/oauth/token')
        .to_return(status: 400, body: { error: 'invalid_grant', error_description: 'Code expired' }.to_json)

      expect {
        service.exchange_code('invalid_code')
      }.to raise_error(Integrations::OAuthError, /Token exchange failed/)
    end

    it 'uses correct content type header' do
      stub_request(:post, 'https://example.com/oauth/token')
        .with(headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
        .to_return(status: 200, body: token_response)

      service.exchange_code('auth_code_123')
    end
  end

  describe '#refresh_token' do
    let(:token_response) do
      {
        access_token: 'refreshed_access_token',
        refresh_token: 'new_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer'
      }.to_json
    end

    it 'refreshes access token' do
      stub_request(:post, 'https://example.com/oauth/token')
        .with(
          body: hash_including(
            'grant_type' => 'refresh_token',
            'refresh_token' => 'old_refresh_token',
            'client_id' => 'test_client_id',
            'client_secret' => 'test_client_secret'
          )
        )
        .to_return(status: 200, body: token_response)

      result = service.refresh_token('old_refresh_token')

      expect(result[:access_token]).to eq('refreshed_access_token')
      expect(result[:refresh_token]).to eq('new_refresh_token')
    end

    it 'raises OAuthError on failure' do
      stub_request(:post, 'https://example.com/oauth/token')
        .to_return(status: 400, body: { error: 'invalid_grant' }.to_json)

      expect {
        service.refresh_token('invalid_token')
      }.to raise_error(Integrations::OAuthError)
    end
  end

  describe '#revoke_token' do
    it 'revokes access token' do
      stub_request(:post, 'https://example.com/oauth/revoke')
        .with(
          body: hash_including(
            'token' => 'access_token_to_revoke',
            'client_id' => 'test_client_id',
            'client_secret' => 'test_client_secret'
          )
        )
        .to_return(status: 200, body: '')

      service.revoke_token('access_token_to_revoke')
    end

    it 'returns nil if no revoke endpoint configured' do
      service_without_revoke = Class.new(Integrations::BaseOauthService) do
        def load_config
          {
            authorize_endpoint: 'https://example.com/oauth/authorize',
            token_endpoint: 'https://example.com/oauth/token',
            client_id: 'test_client_id',
            client_secret: 'test_client_secret'
          }
        end
      end.new(:test)

      result = service_without_revoke.revoke_token('token')
      expect(result).to be_nil
    end
  end

  describe 'protected methods' do
    describe '#generate_state_token' do
      it 'generates a secure random token' do
        token1 = service.send(:generate_state_token)
        token2 = service.send(:generate_state_token)

        expect(token1).not_to eq(token2)
        expect(token1.length).to be > 20
      end
    end

    describe '#format_scopes' do
      it 'formats array scopes as space-separated string' do
        result = service.send(:format_scopes, ['read', 'write', 'admin'])
        expect(result).to eq('read write admin')
      end

      it 'returns string scopes as-is' do
        result = service.send(:format_scopes, 'read write')
        expect(result).to eq('read write')
      end
    end
  end

  describe 'error handling for missing credentials' do
    it 'raises OAuthError when client_id is missing' do
      service_without_creds = Class.new(Integrations::BaseOauthService) do
        def load_config
          {
            authorize_endpoint: 'https://example.com/oauth/authorize',
            token_endpoint: 'https://example.com/oauth/token'
          }
        end
      end.new(:missing_provider)

      allow(CredentialsHelper).to receive(:integration).with(:missing_provider)
        .and_raise(CredentialsHelper::MissingCredentialsError)

      expect {
        service_without_creds.send(:client_id)
      }.to raise_error(Integrations::OAuthError, /Missing client_id/)
    end

    it 'raises OAuthError when client_secret is missing' do
      service_without_creds = Class.new(Integrations::BaseOauthService) do
        def load_config
          {
            authorize_endpoint: 'https://example.com/oauth/authorize',
            token_endpoint: 'https://example.com/oauth/token'
          }
        end
      end.new(:missing_provider)

      allow(CredentialsHelper).to receive(:integration).with(:missing_provider)
        .and_raise(CredentialsHelper::MissingCredentialsError)

      expect {
        service_without_creds.send(:client_secret)
      }.to raise_error(Integrations::OAuthError, /Missing client_secret/)
    end
  end
end
