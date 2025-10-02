# app/jobs/integrations/discord_sync_job.rb
module Integrations
  class DiscordSyncJob < BaseSyncJob
    queue_as :default

    private

    def find_integration_account(account_id)
      DiscordAccount.find(account_id)
    end

    def sync_service_class
      DiscordSyncService
    end
  end
end
