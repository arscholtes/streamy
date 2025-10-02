# app/services/integrations/discord_sync_service.rb
# Syncs Discord profile data
module Integrations
  class DiscordSyncService
    attr_reader :discord_account

    def initialize(discord_account)
      @discord_account = discord_account
      @api_client = DiscordApiClient.new(discord_account)
    end

    def sync!
      ActiveRecord::Base.transaction do
        sync_profile
      end

      discord_account.update!(last_synced_at: Time.current)
    rescue Integrations::APIError => e
      Rails.logger.error("Discord sync failed for account #{discord_account.id}: #{e.message}")
      raise
    end

    private

    def sync_profile
      user_data = @api_client.get_current_user

      discord_account.update!(
        username: user_data['username'],
        discriminator: user_data['discriminator'],
        avatar_url: user_data['avatar'] ? "https://cdn.discordapp.com/avatars/#{user_data['id']}/#{user_data['avatar']}.png" : nil,
        email: user_data['email'],
        verified: user_data['verified'],
        locale: user_data['locale']
      )
    end
  end
end
