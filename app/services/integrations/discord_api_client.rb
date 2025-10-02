# app/services/integrations/discord_api_client.rb
# Discord API client
module Integrations
  class DiscordApiClient < BaseApiClient
    BASE_URL = 'https://discord.com/api/v10'.freeze

    def initialize(discord_account)
      @discord_account = discord_account
      @access_token = discord_account.access_token
      @rate_limiter = RateLimiter.new(requests_per_second: 5, burst: 10)
    end

    def get_current_user
      get('/users/@me')
    end

    def get_guilds
      get('/users/@me/guilds')
    end

    def get_connections
      get('/users/@me/connections')
    end

    private

    def build_url(endpoint)
      "#{BASE_URL}#{endpoint}"
    end

    def default_headers
      {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      }
    end

    def rate_limit_config
      { requests_per_second: 5, burst: 10 }
    end
  end
end
