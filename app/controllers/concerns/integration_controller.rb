# app/controllers/concerns/integration_controller.rb
# Concern for integration controllers
# Provides common OAuth flow actions (connect, callback, disconnect, sync)

module IntegrationController
  extend ActiveSupport::Concern

  included do
    before_action :require_login
    before_action :set_integration_account, only: [:disconnect, :sync, :privacy_settings, :update_privacy_settings]
  end

  # Redirect to OAuth authorization URL
  def connect
    redirect_to oauth_authorize_url, allow_other_host: true
  end

  # Handle OAuth callback
  def callback
    code = params[:code]

    if code.blank?
      redirect_to settings_path, alert: "#{integration_name} connection failed: No authorization code"
      return
    end

    begin
      # Exchange code for tokens
      tokens = oauth_service.exchange_code(code)

      # Fetch user data from API
      user_data = fetch_user_data(tokens[:access_token])

      # Create or update integration account
      integration_account = create_or_update_integration_account(user_data, tokens)

      # Redirect to privacy settings
      redirect_to privacy_settings_path, notice: "#{integration_name} connected successfully!"
    rescue => e
      Rails.logger.error("OAuth callback error: #{e.message}")
      redirect_to settings_path, alert: "Failed to connect #{integration_name}: #{e.message}"
    end
  end

  # Disconnect integration
  def disconnect
    @integration_account.destroy
    redirect_to settings_path, notice: "#{integration_name} disconnected successfully"
  end

  # Manually trigger sync
  def sync
    enqueue_sync_job(@integration_account)
    redirect_to settings_path, notice: "#{integration_name} sync started..."
  end

  # Show privacy settings page
  def privacy_settings
    @privacy_setting = @integration_account.integration_privacy_setting
    @settings_schema = privacy_settings_schema
  end

  # Update privacy settings
  def update_privacy_settings
    privacy_setting = @integration_account.integration_privacy_setting

    if privacy_setting.update(settings: privacy_params)
      redirect_to settings_path, notice: "Privacy settings updated"
    else
      @privacy_setting = privacy_setting
      @settings_schema = privacy_settings_schema
      render :privacy_settings
    end
  end

  private

  # Set integration account from current user
  def set_integration_account
    @integration_account = current_user.send(integration_account_association)

    unless @integration_account
      redirect_to settings_path, alert: "#{integration_name} not connected"
    end
  end

  # Create or update integration account
  def create_or_update_integration_account(user_data, tokens)
    account = current_user.send(integration_account_association) ||
              current_user.send("build_#{integration_account_association}")

    account.assign_attributes(
      integration_account_attributes(user_data, tokens)
    )

    account.expires_in = tokens[:expires_in] # Temporary attribute for HasOauthTokens
    account.save!

    # Enqueue sync job
    enqueue_sync_job(account)

    account
  end

  # Enqueue background sync job
  def enqueue_sync_job(account)
    return unless respond_to?(:sync_job_class, true)
    sync_job_class.perform_later(account.id)
  end

  # Get privacy params from form
  def privacy_params
    params.require(:privacy_settings).permit(
      privacy_settings_schema.values.flatten.map { |s| s[:key] }
    )
  end

  # Override in subclasses to provide OAuth service instance
  # @return [Integrations::BaseOauthService]
  def oauth_service
    raise NotImplementedError, "#{self.class.name} must implement #oauth_service"
  end

  # Override in subclasses to fetch user data from API
  # @param access_token [String]
  # @return [Hash] User data
  def fetch_user_data(access_token)
    raise NotImplementedError, "#{self.class.name} must implement #fetch_user_data"
  end

  # Override in subclasses to build account attributes
  # @param user_data [Hash]
  # @param tokens [Hash]
  # @return [Hash]
  def integration_account_attributes(user_data, tokens)
    raise NotImplementedError, "#{self.class.name} must implement #integration_account_attributes"
  end

  # Override in subclasses to specify account association name
  # @return [Symbol] e.g., :steam_account
  def integration_account_association
    raise NotImplementedError, "#{self.class.name} must implement #integration_account_association"
  end

  # Override in subclasses to specify sync job class
  def sync_job_class
    nil # Optional - some integrations may not need background sync
  end

  # Override in subclasses to define privacy settings schema
  # @return [Hash]
  def privacy_settings_schema
    {
      general: [
        { key: :show_username, label: "Show username", default: true },
        { key: :show_avatar, label: "Show avatar", default: true }
      ]
    }
  end

  # Get integration name from controller
  def integration_name
    self.class.name.demodulize.gsub('Controller', '').titleize
  end

  # Get OAuth authorize URL
  def oauth_authorize_url
    oauth_service.authorize_url(
      scopes: oauth_scopes,
      state: oauth_state
    )
  end

  # OAuth scopes (override in subclasses)
  def oauth_scopes
    []
  end

  # OAuth state parameter (override in subclasses)
  def oauth_state
    nil
  end

  # Privacy settings path (override if custom route)
  def privacy_settings_path
    send("integrations_#{integration_account_association.to_s.split('_').first}_privacy_settings_path")
  rescue
    settings_path
  end
end
