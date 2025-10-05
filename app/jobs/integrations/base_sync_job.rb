module Integrations
  class BaseSyncJob < ApplicationJob
    queue_as :default

    # Retry on API errors with exponential backoff
    retry_on Integrations::APIError, wait: :exponentially_longer, attempts: 5
    retry_on Integrations::RateLimitError, wait: 1.hour, attempts: 3

    def perform(integration_account_id, integration_class_name)
      integration_class = integration_class_name.constantize
      integration_account = integration_class.find_by(id: integration_account_id)

      unless integration_account
        Rails.logger.warn("Integration account not found: #{integration_class_name}##{integration_account_id}")
        return
      end

      # Perform the sync
      sync_service_class = integration_account.sync_service_class
      unless sync_service_class
        Rails.logger.warn("No sync service defined for #{integration_class_name}")
        return
      end

      Rails.logger.info("Starting sync for #{integration_class_name}##{integration_account_id}")

      sync_service = sync_service_class.new(integration_account)
      sync_service.sync!

      integration_account.update(last_synced_at: Time.current)

      Rails.logger.info("Completed sync for #{integration_class_name}##{integration_account_id}")
    rescue StandardError => e
      Rails.logger.error("Sync failed for #{integration_class_name}##{integration_account_id}: #{e.message}")
      raise
    end
  end
end
