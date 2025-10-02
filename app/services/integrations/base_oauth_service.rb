# app/services/integrations/base_oauth_service.rb
# Base OAuth 2.0 service for all integrations
# Provides common OAuth flow methods that can be extended by specific integrations

module Integrations
  class BaseOauthService
    attr_reader :provider, :region

    def initialize(provider, region: nil)
      @provider = provider
      @region = region
    end

    # Generate OAuth authorization URL
    # @param scopes [Array<String>] OAuth scopes to request
    # @param state [String] Optional state parameter for CSRF protection
    # @return [String] Authorization URL
    def authorize_url(scopes: [], state: nil)
      params = {
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: 'code',
        scope: scopes.join(' ')
      }
      params[:state] = state if state.present?

      "#{authorize_endpoint}?#{params.to_query}"
    end

    # Exchange authorization code for access token
    # @param code [String] Authorization code from OAuth callback
    # @return [Hash] Token response with :access_token, :refresh_token, :expires_in
    def exchange_code(code)
      response = HTTParty.post(
        token_endpoint,
        body: {
          grant_type: 'authorization_code',
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri
        },
        headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
      )

      handle_token_response(response)
    end

    # Refresh access token using refresh token
    # @param refresh_token [String] Refresh token
    # @return [Hash] New token response
    def refresh_token(refresh_token)
      response = HTTParty.post(
        token_endpoint,
        body: {
          grant_type: 'refresh_token',
          refresh_token: refresh_token,
          client_id: client_id,
          client_secret: client_secret
        },
        headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
      )

      handle_token_response(response)
    end

    private

    # Load OAuth configuration from Rails credentials
    def oauth_config
      @oauth_config ||= Rails.application.credentials.dig(:integrations, provider) || {}
    end

    def client_id
      region ? oauth_config.dig(region.to_sym, :client_id) : oauth_config[:client_id]
    end

    def client_secret
      region ? oauth_config.dig(region.to_sym, :client_secret) : oauth_config[:client_secret]
    end

    def redirect_uri
      oauth_config[:redirect_uri] || default_redirect_uri
    end

    def default_redirect_uri
      Rails.application.routes.url_helpers.send(
        :"integrations_#{provider}_callback_url",
        host: Rails.application.config.action_mailer.default_url_options[:host]
      )
    end

    # Override in subclasses
    def token_endpoint
      raise NotImplementedError, "#{self.class.name} must implement #token_endpoint"
    end

    # Override in subclasses
    def authorize_endpoint
      raise NotImplementedError, "#{self.class.name} must implement #authorize_endpoint"
    end

    def handle_token_response(response)
      if response.success?
        parsed = JSON.parse(response.body, symbolize_names: true)
        {
          access_token: parsed[:access_token],
          refresh_token: parsed[:refresh_token],
          expires_in: parsed[:expires_in] || 3600,
          token_type: parsed[:token_type] || 'Bearer'
        }
      else
        raise OAuthError, "Token exchange failed: #{response.body}"
      end
    end
  end

  class OAuthError < StandardError; end
end
