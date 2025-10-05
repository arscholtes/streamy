module Integrations
  class BattlenetSyncService
    attr_reader :battlenet_account

    def initialize(battlenet_account)
      @battlenet_account = battlenet_account
      @api_client = BattlenetApiClient.new(battlenet_account)
    end

    def sync!
      ActiveRecord::Base.transaction do
        sync_account_info
        sync_game_profiles
      end

      battlenet_account.update!(last_synced_at: Time.current)
    rescue Integrations::APIError => e
      Rails.logger.error("Battle.net sync failed for account #{battlenet_account.id}: #{e.message}")
      raise
    end

    private

    def sync_account_info
      account_info = @api_client.fetch_account_info

      battlenet_account.update!(
        battletag: account_info[:battletag]
      )
    end

    def sync_game_profiles
      # Sync WoW profile if user has WoW data
      sync_wow_profile if has_wow_access?

      # Sync Diablo 3 profile
      sync_diablo_profile if has_diablo_access?

      # Sync StarCraft 2 profile
      sync_sc2_profile if has_sc2_access?
    end

    def sync_wow_profile
      wow_data = @api_client.fetch_wow_profile

      if wow_data && wow_data[:wow_accounts]
        # Store WoW profile data in metadata
        # This could be expanded to separate tables for characters
        battlenet_account.user.update(
          metadata: (battlenet_account.user.metadata || {}).merge(
            wow_profile: {
              accounts: wow_data[:wow_accounts]&.map { |acc|
                {
                  id: acc[:id],
                  characters: acc[:characters]&.map { |char|
                    {
                      name: char[:name],
                      realm: char[:realm][:name],
                      level: char[:level],
                      class: char[:playable_class][:name],
                      race: char[:playable_race][:name]
                    }
                  }
                }
              },
              updated_at: Time.current
            }
          )
        )
      end
    rescue Integrations::APIError => e
      Rails.logger.warn("Could not sync WoW profile: #{e.message}")
    end

    def sync_diablo_profile
      diablo_data = @api_client.fetch_diablo_profile

      if diablo_data
        # Store Diablo profile in metadata
        battlenet_account.user.update(
          metadata: (battlenet_account.user.metadata || {}).merge(
            diablo_profile: {
              data: diablo_data,
              updated_at: Time.current
            }
          )
        )
      end
    rescue Integrations::APIError => e
      Rails.logger.warn("Could not sync Diablo profile: #{e.message}")
    end

    def sync_sc2_profile
      sc2_data = @api_client.fetch_sc2_profile

      if sc2_data
        # Store SC2 profile in metadata
        battlenet_account.user.update(
          metadata: (battlenet_account.user.metadata || {}).merge(
            sc2_profile: {
              data: sc2_data,
              updated_at: Time.current
            }
          )
        )
      end
    rescue Integrations::APIError => e
      Rails.logger.warn("Could not sync SC2 profile: #{e.message}")
    end

    # Check if user has access to each game
    # Could be enhanced with token scope checking
    def has_wow_access?
      true # Default to true, will fail gracefully if no access
    end

    def has_diablo_access?
      true
    end

    def has_sc2_access?
      true
    end
  end
end
