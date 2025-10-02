# app/jobs/integrations/base_sync_job.rb
# Base background job for syncing integration data from external APIs
# Provides retry logic, error handling, and common sync patterns

module Integrations
  class BaseSyncJob < ApplicationJob
    queue_as :default

    # Retry on API errors with exponential backoff
    retry_on Integrations::APIError,
             wait: :exponentially_longer,
             attempts: 5

    # Retry on rate limit errors with custom wait time
    retry_on Integrations::RateLimitError,
             wait: ->(executions) { executions * 60 },
             attempts: 3

    # Don't retry if record is gone
    discard_on ActiveRecord::RecordNotFound

    def perform(integration_account_id)
      integration_account = find_integration_account(integration_account_id)

      # Check if token is valid
      unless integration_account.ensure_valid_token!
        Rails.logger.warn("Token refresh failed for #{integration_account.class.name}##{integration_account_id}")
        return
      end

      # Perform sync
      sync_service_class.new(integration_account).sync!

      # Update last synced timestamp
      integration_account.update(last_synced_at: Time.current)

      Rails.logger.info("Successfully synced #{integration_account.class.name}##{integration_account_id}")
    rescue => e
      Rails.logger.error("Sync failed for #{integration_account_class.name}##{integration_account_id}: #{e.message}")
      raise e
    end

    private

    # Find the integration account
    # Override in subclasses or implement integration_account_class
    def find_integration_account(id)
      integration_account_class.find(id)
    end

    # Override in subclasses to specify the account model
    def integration_account_class
      raise NotImplementedError, "#{self.class.name} must implement #integration_account_class"
    end

    # Override in subclasses to specify the sync service
    def sync_service_class
      raise NotImplementedError, "#{self.class.name} must implement #sync_service_class"
    end
  end
end
