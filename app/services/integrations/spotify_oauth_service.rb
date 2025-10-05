module Integrations
  class SpotifyOauthService < BaseOauthService
    def initialize
      super(:spotify)
    end

    protected

    def load_config
      {
        authorize_endpoint: 'https://accounts.spotify.com/authorize',
        token_endpoint: 'https://accounts.spotify.com/api/token',
        client_id: CredentialsHelper.spotify.client_id,
        client_secret: CredentialsHelper.spotify.client_secret,
        default_scopes: [
          'user-read-private',
          'user-read-email',
          'user-read-currently-playing',
          'user-read-recently-played',
          'user-top-read',
          'user-read-playback-state'
        ]
      }
    end

    def token_request_headers
      # Spotify requires Basic Auth for token requests
      credentials = Base64.strict_encode64("#{client_id}:#{client_secret}")
      {
        'Authorization' => "Basic #{credentials}",
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    end
  end
end
