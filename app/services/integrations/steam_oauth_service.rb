# app/services/integrations/steam_oauth_service.rb
# Steam OpenID 2.0 authentication service
# Steam uses OpenID instead of OAuth 2.0
module Integrations
  class SteamOauthService
    OPENID_ENDPOINT = 'https://steamcommunity.com/openid/login'.freeze
    STEAM_API_BASE = 'https://api.steampowered.com'.freeze

    def initialize
      @api_key = ENV['STEAM_API_KEY']
      @return_url = ENV['STEAM_RETURN_URL'] || "#{ENV['APP_URL']}/integrations/steam/callback"
    end

    # Generate OpenID login URL
    def authorize_url
      params = {
        'openid.ns' => 'http://specs.openid.net/auth/2.0',
        'openid.mode' => 'checkid_setup',
        'openid.return_to' => @return_url,
        'openid.realm' => ENV['APP_URL'],
        'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
        'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select'
      }

      "#{OPENID_ENDPOINT}?#{URI.encode_www_form(params)}"
    end

    # Verify OpenID response and extract Steam ID
    def verify_and_extract_steam_id(params)
      # Verify the signature
      verification_params = params.dup
      verification_params['openid.mode'] = 'check_authentication'

      response = HTTParty.get(OPENID_ENDPOINT, query: verification_params)

      unless response.body.include?('is_valid:true')
        raise Integrations::AuthenticationError, 'Invalid OpenID signature'
      end

      # Extract Steam ID from claimed_id
      # Format: https://steamcommunity.com/openid/id/76561197960435530
      claimed_id = params['openid.claimed_id']
      steam_id = claimed_id.split('/').last

      steam_id
    end

    # Fetch user profile data from Steam API
    def fetch_user_data(steam_id)
      url = "#{STEAM_API_BASE}/ISteamUser/GetPlayerSummaries/v0002/"

      response = HTTParty.get(url, query: {
        key: @api_key,
        steamids: steam_id
      })

      if response.code == 200 && response.parsed_response['response']['players'].any?
        player = response.parsed_response['response']['players'].first

        {
          steam_id: player['steamid'],
          persona_name: player['personaname'],
          profile_url: player['profileurl'],
          avatar_url: player['avatarfull'],
          real_name: player['realname'],
          country_code: player['loccountrycode'],
          state_code: player['locstatecode'],
          visibility: player['communityvisibilitystate'],
          time_created: player['timecreated'],
          last_logoff: player['lastlogoff']
        }
      else
        raise Integrations::APIError, 'Failed to fetch Steam user data'
      end
    end

    # Steam doesn't use traditional tokens, but we'll create a pseudo-token
    # using the Steam API key and Steam ID for consistency with other integrations
    def generate_pseudo_tokens(steam_id)
      {
        access_token: "steam_#{steam_id}_#{SecureRandom.hex(16)}",
        refresh_token: nil,
        expires_at: 1.year.from_now
      }
    end
  end
end
