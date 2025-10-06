# app/jobs/integrations/battlenet_sync_job.rb
# Background job for syncing Battle.net account data
module Integrations
  class BattlenetSyncJob < BaseSyncJob
    queue_as :default

    private

    def find_integration_account(account_id)
      BattlenetAccount.find(account_id)
    end

    def sync_service_class
      BattlenetSyncService
    end
  end
end
