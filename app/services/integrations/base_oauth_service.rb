require_relative 'errors'

module Integrations
  class BaseOauthService
    include HTTParty

    attr_reader :provider, :config

    def initialize(provider, region: nil)
      @provider = provider
      @region = region
      @config = load_config
    end

    # Generate OAuth authorization URL
    def authorization_url(state: nil, scopes: nil)
      params = {
        client_id: client_id,
        redirect_uri: callback_url,
        response_type: 'code',
        state: state || generate_state_token
      }

      params[:scope] = format_scopes(scopes || default_scopes) if scopes || default_scopes

      "#{authorize_endpoint}?#{params.to_query}"
    end

    # Exchange authorization code for access token
    def exchange_code(code)
      response = self.class.post(
        token_endpoint,
        body: {
          grant_type: 'authorization_code',
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: callback_url
        },
        headers: token_request_headers
      )

      handle_token_response(response)
    end

    # Refresh access token
    def refresh_token(refresh_token)
      response = self.class.post(
        token_endpoint,
        body: {
          grant_type: 'refresh_token',
          refresh_token: refresh_token,
          client_id: client_id,
          client_secret: client_secret
        },
        headers: token_request_headers
      )

      handle_token_response(response)
    end

    # Revoke access token
    def revoke_token(access_token)
      return unless revoke_endpoint

      self.class.post(
        revoke_endpoint,
        body: {
          token: access_token,
          client_id: client_id,
          client_secret: client_secret
        },
        headers: token_request_headers
      )
    end

    protected

    # Override these in subclasses
    def authorize_endpoint
      @config[:authorize_endpoint] || raise(NotImplementedError, "#{self.class} must define authorize_endpoint")
    end

    def token_endpoint
      @config[:token_endpoint] || raise(NotImplementedError, "#{self.class} must define token_endpoint")
    end

    def revoke_endpoint
      @config[:revoke_endpoint]
    end

    def client_id
      @config[:client_id] || CredentialsHelper.integration(provider).client_id
    rescue CredentialsHelper::MissingCredentialsError
      raise OAuthError, "Missing client_id for #{provider}. Please configure credentials."
    end

    def client_secret
      @config[:client_secret] || CredentialsHelper.integration(provider).client_secret
    rescue CredentialsHelper::MissingCredentialsError
      raise OAuthError, "Missing client_secret for #{provider}. Please configure credentials."
    end

    def callback_url
      @config[:callback_url] || Rails.application.routes.url_helpers.send("integrations_#{provider}_callback_url")
    end

    def default_scopes
      @config[:default_scopes] || []
    end

    def token_request_headers
      { 'Content-Type' => 'application/x-www-form-urlencoded' }
    end

    def format_scopes(scopes)
      scopes.is_a?(Array) ? scopes.join(' ') : scopes
    end

    def generate_state_token
      SecureRandom.urlsafe_base64(32)
    end

    def load_config
      # Override in subclass to provide default configuration
      {}
    end

    def handle_token_response(response)
      if response.success?
        parsed = JSON.parse(response.body, symbolize_names: true)

        {
          access_token: parsed[:access_token],
          refresh_token: parsed[:refresh_token],
          expires_in: parsed[:expires_in],
          token_type: parsed[:token_type],
          scope: parsed[:scope]
        }
      else
        error_message = begin
          JSON.parse(response.body)['error_description']
        rescue
          response.body
        end

        raise OAuthError, "Token exchange failed: #{error_message}"
      end
    end
  end

  class OAuthError < StandardError; end
end
