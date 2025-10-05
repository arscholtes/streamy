# app/services/integrations/discord_oauth_service.rb
# Discord OAuth 2.0 authentication service
module Integrations
  class DiscordOauthService < BaseOauthService
    def initialize
      super(:discord)
    end

    protected

    def load_config
      {
        authorize_endpoint: 'https://discord.com/api/oauth2/authorize',
        token_endpoint: 'https://discord.com/api/v10/oauth2/token',
        client_id: CredentialsHelper.discord.client_id,
        client_secret: CredentialsHelper.discord.client_secret,
        default_scopes: ['identify', 'email', 'guilds']
      }
    end
  end
end
