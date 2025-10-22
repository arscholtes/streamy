# app/services/integrations/youtube_oauth_service.rb
# YouTube OAuth 2.0 authentication service
module Integrations
  class YoutubeOauthService < BaseOauthService
    def initialize
      super(:youtube)
    end

    protected

    def load_config
      {
        authorize_endpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
        token_endpoint: 'https://oauth2.googleapis.com/token',
        revoke_endpoint: 'https://oauth2.googleapis.com/revoke',
        client_id: CredentialsHelper.youtube.client_id,
        client_secret: CredentialsHelper.youtube.client_secret,
        default_scopes: [
          'https://www.googleapis.com/auth/youtube.readonly',
          'https://www.googleapis.com/auth/youtube.upload',
          'https://www.googleapis.com/auth/userinfo.profile'
        ]
      }
    end

    # YouTube requires access_type=offline to get refresh tokens
    def authorization_url(state: nil, scopes: nil)
      base_url = super(state: state, scopes: scopes)
      "#{base_url}&access_type=offline&prompt=consent"
    end
  end
end
