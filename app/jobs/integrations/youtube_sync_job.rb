# app/jobs/integrations/youtube_sync_job.rb
module Integrations
  class YoutubeSyncJob < BaseSyncJob
    queue_as :default

    private

    def find_integration_account(account_id)
      YoutubeAccount.find(account_id)
    end

    def sync_service_class
      YoutubeSyncService
    end
  end
end
