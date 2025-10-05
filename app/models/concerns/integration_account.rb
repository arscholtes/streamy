module IntegrationAccount
  extend ActiveSupport::Concern

  included do
    include HasOauthTokens

    belongs_to :user
    has_one :integration_privacy_setting, as: :integration, dependent: :destroy

    # Validate external ID presence and uniqueness
    validates_with ExternalIdValidator, if: -> { respond_to?(:external_id_field) }

    after_create :create_default_privacy_settings
    after_create :enqueue_initial_sync
  end

  # Trigger a sync of data from the external service
  def sync!
    return false unless sync_service_class

    begin
      sync_service_class.new(self).sync!
      update(last_synced_at: Time.current)
      true
    rescue StandardError => e
      Rails.logger.error("Sync failed for #{self.class}: #{e.message}")
      false
    end
  end

  # Check if account needs syncing (last sync > 24 hours ago)
  def needs_sync?
    last_synced_at.nil? || last_synced_at < 24.hours.ago
  end

  # Get the display name for this integration
  def display_name
    # Try common display name fields
    %w[display_name username name persona_name gamertag online_id].each do |field|
      return send(field) if respond_to?(field) && send(field).present?
    end

    integration_provider.to_s.titleize
  end

  # Check if integration is connected and valid
  def connected?
    persisted? && access_token.present? && !token_expired?
  end

  protected

  # Override in model to specify the sync service class
  def sync_service_class
    nil # Optional - not all integrations need syncing
  end

  # Override in model to specify default privacy settings
  def default_privacy_settings
    {} # Override in model
  end

  private

  def create_default_privacy_settings
    return if integration_privacy_setting.present?

    create_integration_privacy_setting!(
      user: user,
      settings: default_privacy_settings
    )
  end

  def enqueue_initial_sync
    return unless sync_service_class

    # TODO: Enqueue sync job (requires Base Sync Job)
    # sync_job_class.perform_later(id) if respond_to?(:sync_job_class)
  end

  # Validator for external ID fields
  class ExternalIdValidator < ActiveModel::Validator
    def validate(record)
      field = record.external_id_field
      return unless field

      if record.send(field).blank?
        record.errors.add(field, "can't be blank")
      end

      # Check uniqueness
      existing = record.class.where(field => record.send(field))
                       .where.not(id: record.id)
                       .first

      if existing
        record.errors.add(field, "has already been taken")
      end
    end
  end
end
