# app/jobs/integrations/riot_sync_job.rb
# Background job for syncing Riot account data
module Integrations
  class RiotSyncJob < BaseSyncJob
    queue_as :default

    private

    def find_integration_account(account_id)
      RiotAccount.find(account_id)
    end

    def sync_service_class
      RiotSyncService
    end
  end
end
