# app/services/integrations/steam_sync_service.rb
# Syncs Steam profile data, owned games, recent games, and achievements
module Integrations
  class SteamSyncService
    attr_reader :steam_account

    def initialize(steam_account)
      @steam_account = steam_account
      @api_client = SteamApiClient.new(steam_account)
      @oauth_service = SteamOauthService.new
    end

    # Main sync method
    def sync!
      ActiveRecord::Base.transaction do
        sync_profile
        sync_steam_level
        # Additional syncs can be added as needed
        # sync_owned_games
        # sync_recent_games
        # sync_achievements
      end

      steam_account.update!(last_synced_at: Time.current)
    rescue Integrations::APIError => e
      Rails.logger.error("Steam sync failed for account #{steam_account.id}: #{e.message}")
      raise
    end

    private

    # Sync basic profile information
    def sync_profile
      profile_data = @oauth_service.fetch_user_data(steam_account.steam_id)

      steam_account.update!(
        persona_name: profile_data[:persona_name],
        profile_url: profile_data[:profile_url],
        avatar_url: profile_data[:avatar_url],
        real_name: profile_data[:real_name],
        country_code: profile_data[:country_code],
        state_code: profile_data[:state_code],
        visibility: profile_data[:visibility],
        time_created: profile_data[:time_created],
        last_logoff: profile_data[:last_logoff]
      )
    end

    # Sync Steam level
    def sync_steam_level
      level_data = @api_client.get_steam_level

      if level_data && level_data['response']
        steam_account.update!(level: level_data['response']['player_level'])
      end
    rescue Integrations::APIError => e
      Rails.logger.warn("Could not fetch Steam level: #{e.message}")
    end

    # Future: Sync owned games
    # This would require a separate SteamGame model
    def sync_owned_games
      games_data = @api_client.get_owned_games

      if games_data && games_data['response']['games']
        games_data['response']['games'].each do |game|
          # Store in SteamGame model (to be created)
          # SteamGame.find_or_create_by(
          #   steam_account: steam_account,
          #   app_id: game['appid']
          # ).update!(
          #   name: game['name'],
          #   playtime_forever: game['playtime_forever'],
          #   playtime_2weeks: game['playtime_2weeks'],
          #   img_icon_url: game['img_icon_url'],
          #   img_logo_url: game['img_logo_url']
          # )
        end
      end
    end

    # Future: Sync recently played games
    def sync_recent_games
      recent_data = @api_client.get_recent_games

      if recent_data && recent_data['response']['games']
        # Update recent games with playtime
      end
    end

    # Future: Sync achievements for top games
    def sync_achievements
      # Fetch achievements for user's most played games
    end
  end
end
