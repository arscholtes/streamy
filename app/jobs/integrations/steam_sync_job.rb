# app/jobs/integrations/steam_sync_job.rb
# Background job for syncing Steam account data
module Integrations
  class SteamSyncJob < BaseSyncJob
    queue_as :default

    private

    def find_integration_account(account_id)
      SteamAccount.find(account_id)
    end

    def sync_service_class
      SteamSyncService
    end
  end
end
