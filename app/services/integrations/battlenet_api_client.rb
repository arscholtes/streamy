module Integrations
  class BattlenetApiClient < BaseApiClient
    def api_base_url
      region = integration_account.region || 'us'

      case region.to_sym
      when :us
        'https://us.api.blizzard.com'
      when :eu
        'https://eu.api.blizzard.com'
      when :kr
        'https://kr.api.blizzard.com'
      when :tw
        'https://tw.api.blizzard.com'
      when :cn
        'https://gateway.battlenet.com.cn'
      else
        'https://us.api.blizzard.com'
      end
    end

    def oauth_base_url
      region = integration_account.region || 'us'
      region.to_sym == :cn ? 'https://oauth.battlenet.com.cn' : 'https://oauth.battle.net'
    end

    # Get user profile (BattleTag, etc.)
    def fetch_user_profile
      get('/oauth/userinfo')
    end

    # World of Warcraft methods
    def fetch_wow_profile
      get('/profile/user/wow', params: { namespace: "profile-#{integration_account.region}" })
    end

    def fetch_wow_character(realm_slug, character_name)
      get(
        "/profile/wow/character/#{realm_slug}/#{character_name.downcase}",
        params: { namespace: "profile-#{integration_account.region}", locale: 'en_US' }
      )
    end

    # Diablo 3 methods
    def fetch_diablo_profile
      get('/d3/profile/user/index', params: { locale: 'en_US' })
    end

    # StarCraft 2 methods
    def fetch_sc2_profile
      get('/sc2/profile/user')
    end

    # Overwatch methods (limited API support)
    def fetch_overwatch_summary
      # Note: Overwatch has very limited API support
      # This would require additional implementation
      {}
    end

    # Account information
    def fetch_account_info
      response = get('/oauth/userinfo')

      {
        battletag: response[:battletag],
        id: response[:id],
        sub: response[:sub]
      }
    end
  end
end
