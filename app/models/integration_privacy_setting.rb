# app/models/integration_privacy_setting.rb
# Polymorphic model for storing privacy settings for any integration
# Uses JSON column to store flexible key-value settings

class IntegrationPrivacySetting < ApplicationRecord
  # Polymorphic association - can belong to any integration account
  belongs_to :integration, polymorphic: true
  belongs_to :user

  # Store settings as JSON (Rails 7+)
  # Allows flexible schema per integration
  store :settings, accessors: [], coder: JSON

  # Validations
  validates :integration, presence: true
  validates :user, presence: true

  # Get setting value
  # @param key [Symbol, String] Setting key
  # @return [Boolean] Setting value (defaults to false if not set)
  def show?(key)
    # Default to false for privacy - user must explicitly enable
    settings[key.to_s] == true
  end

  # Update a single setting
  # @param key [Symbol, String] Setting key
  # @param value [Boolean] Setting value
  # @return [Boolean] Save success
  def update_setting(key, value)
    self.settings = settings.merge(key.to_s => value)
    save
  end

  # Bulk update settings
  # @param new_settings [Hash] Hash of settings to update
  # @return [Boolean] Save success
  def update_settings(new_settings)
    self.settings = settings.merge(new_settings.stringify_keys)
    save
  end

  # Get all enabled settings
  # @return [Array<String>] Array of enabled setting keys
  def enabled_settings
    settings.select { |_, v| v == true }.keys
  end

  # Get all disabled settings
  # @return [Array<String>] Array of disabled setting keys
  def disabled_settings
    settings.select { |_, v| v == false }.keys
  end

  # Check if setting exists
  # @param key [Symbol, String]
  # @return [Boolean]
  def setting_exists?(key)
    settings.key?(key.to_s)
  end

  # Reset to defaults
  # @param defaults [Hash] Default settings
  # @return [Boolean] Save success
  def reset_to_defaults!(defaults = {})
    self.settings = defaults.stringify_keys
    save!
  end

  # Get settings as hash with boolean values
  # @return [Hash]
  def to_h
    settings.transform_values { |v| v == true }
  end
end
