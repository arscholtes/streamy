module Integrations
  class RiotApiClient < BaseApiClient
    # Riot has different regional APIs
    REGIONAL_ENDPOINTS = {
      # Americas
      'na1' => 'americas',
      'br1' => 'americas',
      'la1' => 'americas',
      'la2' => 'americas',

      # Europe
      'eun1' => 'europe',
      'euw1' => 'europe',
      'tr1' => 'europe',
      'ru' => 'europe',

      # Asia
      'jp1' => 'asia',
      'kr' => 'asia',
      'oc1' => 'sea',
      'ph2' => 'sea',
      'sg2' => 'sea',
      'th2' => 'sea',
      'tw2' => 'sea',
      'vn2' => 'sea'
    }.freeze

    def api_base_url
      platform = integration_account.region || 'na1'
      "https://#{platform}.api.riotgames.com"
    end

    def regional_api_base_url
      platform = integration_account.region || 'na1'
      region = REGIONAL_ENDPOINTS[platform] || 'americas'
      "https://#{region}.api.riotgames.com"
    end

    # Account API (uses RSO token)
    def fetch_account_info
      response = self.class.get(
        'https://americas.api.riotgames.com/riot/account/v1/accounts/me',
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Accept' => 'application/json'
        }
      )

      handle_response(response)
    end

    # League of Legends methods
    def fetch_lol_summoner_by_puuid(puuid)
      get("/lol/summoner/v4/summoners/by-puuid/#{puuid}")
    end

    def fetch_lol_ranked_stats(summoner_id)
      get("/lol/league/v4/entries/by-summoner/#{summoner_id}")
    end

    def fetch_lol_champion_mastery(puuid)
      get("/lol/champion-mastery/v4/champion-masteries/by-puuid/#{puuid}")
    end

    def fetch_lol_match_history(puuid, count: 20)
      match_ids = get(
        "/lol/match/v5/matches/by-puuid/#{puuid}/ids",
        params: { count: count }
      )

      match_ids&.first(5)&.map do |match_id|
        fetch_lol_match(match_id)
      end
    end

    def fetch_lol_match(match_id)
      response = self.class.get(
        "#{regional_api_base_url}/lol/match/v5/matches/#{match_id}",
        headers: default_headers
      )
      handle_response(response)
    end

    # Valorant methods
    def fetch_valorant_account(puuid)
      # Note: Valorant API has limited public access
      # Most endpoints require production credentials
      get("/val/account/v1/accounts/by-puuid/#{puuid}")
    rescue Integrations::ForbiddenError
      Rails.logger.warn("Valorant API access not available")
      nil
    end

    # Teamfight Tactics methods
    def fetch_tft_summoner_by_puuid(puuid)
      get("/tft/summoner/v1/summoners/by-puuid/#{puuid}")
    end

    def fetch_tft_ranked_stats(summoner_id)
      get("/tft/league/v1/entries/by-summoner/#{summoner_id}")
    end

    # Override to add API key to all requests
    def default_headers
      {
        'Authorization' => "Bearer #{access_token}",
        'X-Riot-Token' => CredentialsHelper.riot.api_key,
        'Accept' => 'application/json'
      }
    rescue CredentialsHelper::MissingCredentialsError
      raise Integrations::APIError, "Missing Riot API key. Please configure credentials."
    end
  end
end
