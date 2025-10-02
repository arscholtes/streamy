# app/models/concerns/integration_account.rb
# Concern for integration account models (SteamAccount, DiscordAccount, etc.)
# Provides common associations, validations, and methods

module IntegrationAccount
  extend ActiveSupport::Concern

  included do
    include HasOauthTokens

    # Associations
    belongs_to :user

    # Validations
    validates :external_id, presence: true, uniqueness: true

    # Privacy settings (polymorphic association)
    has_one :integration_privacy_setting,
            as: :integration,
            dependent: :destroy

    # Callbacks
    after_create :create_default_privacy_settings
    after_create :enqueue_initial_sync
  end

  class_methods do
    # Get the integration name (e.g., "steam" for SteamAccount)
    def integration_name
      name.demodulize.gsub('Account', '').underscore
    end

    # Find account by external ID
    def find_by_external_id(external_id)
      find_by(external_id: external_id)
    end

    # Find or create by external ID
    def find_or_create_by_external_id!(external_id, attributes = {})
      find_or_create_by!(external_id: external_id) do |account|
        attributes.each { |key, value| account.send("#{key}=", value) }
      end
    end
  end

  # Sync data from external API
  # @return [Boolean] Success status
  def sync!
    return false unless respond_to?(:sync_service_class)

    begin
      sync_service_class.new(self).sync!
      update(last_synced_at: Time.current)
      true
    rescue => e
      Rails.logger.error("Sync failed for #{self.class.name}##{id}: #{e.message}")
      false
    end
  end

  # Check if sync is needed (hasn't been synced in 24 hours)
  # @return [Boolean]
  def needs_sync?
    last_synced_at.nil? || last_synced_at < 24.hours.ago
  end

  # Get privacy setting value
  # @param key [Symbol, String] Privacy setting key
  # @return [Boolean] Whether this data should be shown
  def show?(key)
    integration_privacy_setting&.show?(key) || false
  end

  # Get the integration display name
  # @return [String]
  def integration_display_name
    self.class.integration_name.titleize
  end

  # Check if account is connected and valid
  # @return [Boolean]
  def connected?
    persisted? && !token_expired?
  end

  # Disconnect (destroy) this integration
  def disconnect!
    destroy
  end

  private

  # Create default privacy settings after account creation
  def create_default_privacy_settings
    return if integration_privacy_setting.present?

    IntegrationPrivacySetting.create!(
      integration: self,
      user: user,
      settings: default_privacy_settings
    )
  end

  # Default privacy settings (can be overridden in subclasses)
  # @return [Hash]
  def default_privacy_settings
    {
      show_username: true,
      show_avatar: true,
      show_profile_url: true,
      show_stats: false,
      show_library: false
    }
  end

  # Enqueue initial sync job after creation
  def enqueue_initial_sync
    return unless respond_to?(:sync_job_class)
    sync_job_class.perform_later(id)
  end

  # Override in subclasses to specify OAuth service
  def oauth_service_class
    raise NotImplementedError, "#{self.class.name} must implement #oauth_service_class"
  end

  # Override in subclasses to specify sync service
  def sync_service_class
    raise NotImplementedError, "#{self.class.name} must implement #sync_service_class"
  end

  # Override in subclasses to specify sync job
  def sync_job_class
    raise NotImplementedError, "#{self.class.name} must implement #sync_job_class"
  end
end
