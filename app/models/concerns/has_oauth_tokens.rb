module HasOauthTokens
  extend ActiveSupport::Concern

  included do
    # Encrypt sensitive token fields
    encrypts :access_token, :refresh_token if respond_to?(:encrypts)

    validates :access_token, presence: true
  end

  # Check if token has expired
  def token_expired?
    return false unless token_expires_at
    token_expires_at < Time.current
  end

  # Check if token will expire soon (within 5 minutes)
  def token_expiring_soon?
    return false unless token_expires_at
    token_expires_at < 5.minutes.from_now
  end

  # Auto-refresh token if expired or expiring soon
  def ensure_valid_token!
    refresh_oauth_token! if token_expired? || token_expiring_soon?
  end

  # Refresh the access token
  def refresh_oauth_token!
    return false unless refresh_token.present?

    begin
      oauth_service = oauth_service_class.new(integration_provider)
      tokens = oauth_service.refresh_token(refresh_token)

      update!(
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token] || refresh_token,
        token_expires_at: calculate_expiration(tokens[:expires_in])
      )

      true
    rescue StandardError => e
      Rails.logger.error("Token refresh failed for #{self.class}: #{e.message}")
      false
    end
  end

  # Calculate token expiration time
  def calculate_expiration(expires_in)
    return nil unless expires_in
    (expires_in.to_i - 300).seconds.from_now # Subtract 5 minutes as buffer
  end

  # Override in model to specify the OAuth service class
  def oauth_service_class
    raise NotImplementedError, "#{self.class} must define oauth_service_class"
  end

  # Override in model to specify the integration provider name
  def integration_provider
    self.class.name.underscore.gsub('_account', '').to_sym
  end
end
