module Integrations
  class RiotOauthService < BaseOauthService
    def initialize
      super(:riot)
    end

    protected

    def load_config
      {
        authorize_endpoint: 'https://auth.riotgames.com/authorize',
        token_endpoint: 'https://auth.riotgames.com/token',
        revoke_endpoint: 'https://auth.riotgames.com/revoke',
        client_id: CredentialsHelper.riot.client_id,
        client_secret: CredentialsHelper.riot.client_secret,
        default_scopes: ['openid', 'offline_access', 'account', 'summoner']
      }
    end

    def token_request_headers
      # Riot requires Basic Auth for token requests
      credentials = Base64.strict_encode64("#{client_id}:#{client_secret}")
      {
        'Authorization' => "Basic #{credentials}",
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    end
  end
end
