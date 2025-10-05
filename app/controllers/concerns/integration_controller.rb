module IntegrationController
  extend ActiveSupport::Concern

  included do
    before_action :require_login
  end

  # GET /integrations/:provider/connect
  def connect
    redirect_to oauth_authorize_url, allow_other_host: true
  end

  # GET /integrations/:provider/callback
  def callback
    code = params[:code]

    if code.blank?
      flash[:error] = "#{integration_name} authorization failed"
      redirect_to settings_path and return
    end

    begin
      # Exchange code for tokens
      tokens = oauth_service.exchange_code(code)

      # Fetch user profile data
      profile_data = fetch_user_profile(tokens[:access_token])

      # Create or update integration account
      integration_account = create_or_update_account(profile_data, tokens)

      # Enqueue sync job if available
      enqueue_sync_job(integration_account) if integration_account.respond_to?(:sync_service_class)

      flash[:success] = "#{integration_name} connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("#{integration_name} connection error: #{e.message}")
      flash[:error] = "Failed to connect #{integration_name} account"
      redirect_to settings_path
    end
  end

  # DELETE /integrations/:provider/disconnect
  def disconnect
    current_user.send(integration_account_association)&.destroy
    flash[:success] = "#{integration_name} account disconnected"
    redirect_to settings_path
  end

  # POST /integrations/:provider/sync
  def sync
    integration_account = current_user.send(integration_account_association)

    unless integration_account
      flash[:error] = "No #{integration_name} account connected"
      redirect_to settings_path and return
    end

    enqueue_sync_job(integration_account)

    flash[:success] = "#{integration_name} sync started"
    redirect_to settings_path
  end

  protected

  # Override in controller to specify the OAuth service
  def oauth_service
    oauth_service_class.new
  end

  def oauth_service_class
    raise NotImplementedError, "#{self.class} must define oauth_service_class"
  end

  # Override in controller to specify the integration provider name
  def integration_provider
    controller_name.to_sym
  end

  # Override in controller to specify the user association name
  def integration_account_association
    "#{integration_provider}_account".to_sym
  end

  # Override in controller to specify the account model class
  def integration_account_class
    "#{integration_provider.to_s.camelize}Account".constantize
  end

  # Override in controller to specify the integration display name
  def integration_name
    integration_provider.to_s.titleize
  end

  # Override in controller to fetch user profile from API
  def fetch_user_profile(access_token)
    raise NotImplementedError, "#{self.class} must define fetch_user_profile"
  end

  # Create or update the integration account
  def create_or_update_account(profile_data, tokens)
    integration_account = current_user.send(integration_account_association) ||
                         current_user.send("build_#{integration_account_association}")

    integration_account.assign_attributes(
      build_account_attributes(profile_data, tokens)
    )

    integration_account.save!
    integration_account
  end

  # Override in controller to specify account attributes
  def build_account_attributes(profile_data, tokens)
    {
      access_token: tokens[:access_token],
      refresh_token: tokens[:refresh_token],
      token_expires_at: calculate_token_expiration(tokens[:expires_in])
    }.merge(profile_data)
  end

  def calculate_token_expiration(expires_in)
    return nil unless expires_in
    (expires_in.to_i - 300).seconds.from_now
  end

  def oauth_authorize_url
    oauth_service.authorization_url(
      state: SecureRandom.urlsafe_base64(32)
    )
  end

  def enqueue_sync_job(integration_account)
    Integrations::BaseSyncJob.perform_later(
      integration_account.id,
      integration_account.class.name
    )
  end
end
