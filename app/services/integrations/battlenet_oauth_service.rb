module Integrations
  class BattlenetOauthService < BaseOauthService
    # Battle.net supports multiple regions
    REGIONS = {
      us: 'https://oauth.battle.net',
      eu: 'https://oauth.battle.net',
      kr: 'https://oauth.battle.net',
      tw: 'https://oauth.battle.net',
      cn: 'https://oauth.battlenet.com.cn'
    }.freeze

    def initialize(region: :us)
      @region = region.to_sym
      super(:battlenet, region: @region)
    end

    protected

    def load_config
      base_url = REGIONS[@region]

      {
        authorize_endpoint: "#{base_url}/authorize",
        token_endpoint: "#{base_url}/token",
        client_id: CredentialsHelper.battlenet.client_id,
        client_secret: CredentialsHelper.battlenet.client_secret,
        default_scopes: ['wow.profile', 'sc2.profile', 'd3.profile', 'openid']
      }
    end

    # Battle.net requires region in API calls
    def api_base_url
      case @region
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
  end
end
