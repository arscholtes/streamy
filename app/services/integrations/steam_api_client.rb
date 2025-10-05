# app/services/integrations/steam_api_client.rb
# Steam Web API client for fetching games, achievements, etc.
module Integrations
  class SteamApiClient < BaseApiClient
    BASE_URL = 'https://api.steampowered.com'.freeze

    def initialize(steam_account)
      @steam_account = steam_account
      @api_key = CredentialsHelper.steam.api_key
      @steam_id = steam_account.steam_id
      # Steam doesn't have traditional rate limits, but we'll be conservative
      @rate_limiter = RateLimiter.new(requests_per_second: 10, burst: 50)
    rescue CredentialsHelper::MissingCredentialsError
      raise Integrations::APIError, "Missing Steam API key. Please configure credentials."
    end

    # Get owned games
    def get_owned_games(include_free: true)
      get('/IPlayerService/GetOwnedGames/v0001/', params: {
        steamid: @steam_id,
        key: @api_key,
        include_appinfo: 1,
        include_played_free_games: include_free ? 1 : 0
      })
    end

    # Get recently played games (last 2 weeks)
    def get_recent_games(count: 10)
      get('/IPlayerService/GetRecentlyPlayedGames/v0001/', params: {
        steamid: @steam_id,
        key: @api_key,
        count: count
      })
    end

    # Get achievements for a specific game
    def get_achievements(app_id)
      get('/ISteamUserStats/GetPlayerAchievements/v0001/', params: {
        steamid: @steam_id,
        appid: app_id,
        key: @api_key
      })
    rescue Integrations::APIError => e
      # Some games don't have achievements
      { playerstats: { achievements: [] } }
    end

    # Get user stats for a specific game
    def get_user_stats(app_id)
      get('/ISteamUserStats/GetUserStatsForGame/v0002/', params: {
        steamid: @steam_id,
        appid: app_id,
        key: @api_key
      })
    rescue Integrations::APIError => e
      { playerstats: { stats: [] } }
    end

    # Get Steam level
    def get_steam_level
      get('/IPlayerService/GetSteamLevel/v1/', params: {
        steamid: @steam_id,
        key: @api_key
      })
    end

    # Get friends list
    def get_friends_list
      get('/ISteamUser/GetFriendList/v0001/', params: {
        steamid: @steam_id,
        key: @api_key,
        relationship: 'friend'
      })
    end

    private

    def build_url(endpoint)
      "#{BASE_URL}#{endpoint}"
    end

    def default_headers
      {
        'Accept' => 'application/json'
      }
    end

    def rate_limit_config
      { requests_per_second: 10, burst: 50 }
    end

    # Steam API doesn't use OAuth tokens, so we override this
    def make_request(method, endpoint, params: {}, body: {}, retry_count: 0)
      @rate_limiter.wait_if_needed

      response = self.class.send(
        method,
        build_url(endpoint),
        query: params,
        body: body,
        headers: default_headers,
        timeout: 30
      )

      handle_response(response)
    rescue Integrations::RateLimitError => e
      if retry_count < 3
        sleep_duration = (2 ** retry_count) * 1
        sleep(sleep_duration)
        make_request(method, endpoint, params: params, body: body, retry_count: retry_count + 1)
      else
        raise
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Integrations::TimeoutError, "Request timeout: #{e.message}"
    end

    def handle_response(response)
      case response.code
      when 200..299
        parse_response(response)
      when 400
        raise Integrations::APIError, "Bad request: #{response.body}"
      when 401
        raise Integrations::AuthenticationError, "Invalid API key"
      when 403
        raise Integrations::AuthorizationError, "Access forbidden"
      when 429
        raise Integrations::RateLimitError, "Rate limit exceeded"
      when 500..599
        raise Integrations::APIError, "Steam API error: #{response.code}"
      else
        raise Integrations::APIError, "Unexpected response: #{response.code}"
      end
    end

    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Integrations::APIError, "Invalid JSON response: #{e.message}"
    end
  end
end
