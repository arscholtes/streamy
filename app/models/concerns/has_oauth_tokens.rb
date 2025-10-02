# app/models/concerns/has_oauth_tokens.rb
# Concern for models that store OAuth tokens
# Provides encryption, expiration checking, and automatic refresh logic

module HasOauthTokens
  extend ActiveSupport::Concern

  included do
    # Encrypt sensitive token data
    encrypts :access_token, :refresh_token, deterministic: false

    # Validations
    validates :access_token, presence: true

    # Callbacks
    before_save :set_token_expiration, if: -> { access_token_changed? && expires_in.present? }
  end

  # Check if token has expired
  # @return [Boolean]
  def token_expired?
    return false unless token_expires_at.present?
    token_expires_at < Time.current
  end

  # Check if token is about to expire (within 5 minutes)
  # @return [Boolean]
  def token_expiring_soon?
    return false unless token_expires_at.present?
    token_expires_at < 5.minutes.from_now
  end

  # Refresh the access token using the refresh token
  # @return [Boolean] Success status
  def refresh_token!
    return false unless refresh_token.present?
    return false unless respond_to?(:oauth_service_class)

    begin
      service = oauth_service_class.new
      new_tokens = service.refresh_token(refresh_token)

      update!(
        access_token: new_tokens[:access_token],
        refresh_token: new_tokens[:refresh_token] || refresh_token,
        token_expires_at: calculate_expiration(new_tokens[:expires_in])
      )

      true
    rescue Integrations::OAuthError => e
      Rails.logger.error("Token refresh failed for #{self.class.name}##{id}: #{e.message}")
      false
    end
  end

  # Ensure token is valid (refresh if expired)
  # @return [Boolean] Whether token is valid after check
  def ensure_valid_token!
    return true unless token_expired? || token_expiring_soon?
    refresh_token!
  end

  # Get time until token expires
  # @return [ActiveSupport::Duration, nil]
  def time_until_expiration
    return nil unless token_expires_at.present?
    token_expires_at - Time.current
  end

  private

  # Set token expiration time based on expires_in value
  def set_token_expiration
    self.token_expires_at = calculate_expiration(expires_in) if expires_in.present?
  end

  # Calculate expiration time from expires_in seconds
  # Add a small buffer to prevent edge cases
  def calculate_expiration(seconds)
    return nil unless seconds.present?
    (seconds - 60).seconds.from_now # 60 second buffer
  end

  # Temporary attribute for storing expires_in during creation
  attr_accessor :expires_in
end
