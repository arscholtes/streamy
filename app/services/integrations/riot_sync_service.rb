module Integrations
  class RiotSyncService
    attr_reader :riot_account

    def initialize(riot_account)
      @riot_account = riot_account
      @api_client = RiotApiClient.new(riot_account)
    end

    def sync!
      ActiveRecord::Base.transaction do
        sync_account_info
        sync_league_of_legends
        sync_teamfight_tactics
        sync_valorant
      end

      riot_account.update!(last_synced_at: Time.current)
    rescue Integrations::APIError => e
      Rails.logger.error("Riot sync failed for account #{riot_account.id}: #{e.message}")
      raise
    end

    private

    def sync_account_info
      # Account info should already be set during OAuth
      # This method can refresh it if needed
      begin
        account_info = @api_client.fetch_account_info

        riot_account.update!(
          puuid: account_info[:puuid],
          game_name: account_info[:gameName],
          tag_line: account_info[:tagLine]
        )
      rescue Integrations::APIError => e
        Rails.logger.warn("Could not refresh Riot account info: #{e.message}")
      end
    end

    def sync_league_of_legends
      begin
        summoner = @api_client.fetch_lol_summoner_by_puuid(riot_account.puuid)
        return unless summoner

        # Fetch ranked stats
        ranked_stats = @api_client.fetch_lol_ranked_stats(summoner[:id])

        # Fetch champion mastery (top 10)
        champion_mastery = @api_client.fetch_lol_champion_mastery(riot_account.puuid)
        top_champions = champion_mastery&.first(10)

        # Store LoL data in user metadata
        riot_account.user.update(
          metadata: (riot_account.user.metadata || {}).merge(
            lol_profile: {
              summoner_id: summoner[:id],
              summoner_name: summoner[:name],
              summoner_level: summoner[:summonerLevel],
              profile_icon_id: summoner[:profileIconId],
              ranked_stats: ranked_stats&.map { |rank|
                {
                  queue_type: rank[:queueType],
                  tier: rank[:tier],
                  rank: rank[:rank],
                  league_points: rank[:leaguePoints],
                  wins: rank[:wins],
                  losses: rank[:losses]
                }
              },
              top_champions: top_champions&.map { |champ|
                {
                  champion_id: champ[:championId],
                  champion_level: champ[:championLevel],
                  champion_points: champ[:championPoints]
                }
              },
              updated_at: Time.current
            }
          )
        )
      rescue Integrations::APIError => e
        Rails.logger.warn("Could not sync League of Legends data: #{e.message}")
      end
    end

    def sync_teamfight_tactics
      begin
        summoner = @api_client.fetch_tft_summoner_by_puuid(riot_account.puuid)
        return unless summoner

        # Fetch TFT ranked stats
        ranked_stats = @api_client.fetch_tft_ranked_stats(summoner[:id])

        # Store TFT data in user metadata
        riot_account.user.update(
          metadata: (riot_account.user.metadata || {}).merge(
            tft_profile: {
              summoner_id: summoner[:id],
              summoner_name: summoner[:name],
              summoner_level: summoner[:summonerLevel],
              ranked_stats: ranked_stats&.map { |rank|
                {
                  queue_type: rank[:queueType],
                  tier: rank[:tier],
                  rank: rank[:rank],
                  league_points: rank[:leaguePoints],
                  wins: rank[:wins],
                  losses: rank[:losses]
                }
              },
              updated_at: Time.current
            }
          )
        )
      rescue Integrations::APIError => e
        Rails.logger.warn("Could not sync TFT data: #{e.message}")
      end
    end

    def sync_valorant
      begin
        # Valorant API has very limited public access
        # Most endpoints require production credentials
        valorant_account = @api_client.fetch_valorant_account(riot_account.puuid)

        if valorant_account
          riot_account.user.update(
            metadata: (riot_account.user.metadata || {}).merge(
              valorant_profile: {
                data: valorant_account,
                updated_at: Time.current
              }
            )
          )
        end
      rescue Integrations::APIError => e
        Rails.logger.warn("Could not sync Valorant data: #{e.message}")
      end
    end
  end
end
