# app/services/integrations/discord_api_client.rb
# Discord API client
module Integrations
  class DiscordApiClient < BaseApiClient
    def api_base_url
      'https://discord.com/api/v10'
    end

    # Get current user's profile
    def fetch_user_profile
      get('/users/@me')
    end

    # Get user's guilds (servers)
    def fetch_user_guilds
      get('/users/@me/guilds')
    end

    # Get user's connections
    def fetch_user_connections
      get('/users/@me/connections')
    end

    # Get guild member info
    def fetch_guild_member(guild_id)
      get("/users/@me/guilds/#{guild_id}/member")
    end
  end
end
