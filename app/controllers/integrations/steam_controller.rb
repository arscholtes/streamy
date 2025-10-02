# app/controllers/integrations/steam_controller.rb
# Handles Steam integration OAuth flow and management
module Integrations
  class SteamController < ApplicationController
    include IntegrationController

    before_action :set_steam_account, only: [:disconnect, :sync, :privacy_settings, :update_privacy_settings]

    private

    def set_steam_account
      @integration_account = current_user.steam_account
      redirect_to settings_path, alert: 'Steam account not connected' unless @integration_account
    end

    def oauth_service
      @oauth_service ||= SteamOauthService.new
    end

    def oauth_authorize_url
      oauth_service.authorize_url
    end

    def fetch_user_data(params)
      # Verify OpenID response and get Steam ID
      steam_id = oauth_service.verify_and_extract_steam_id(params)

      # Fetch user profile data
      oauth_service.fetch_user_data(steam_id)
    end

    def create_or_update_integration_account(user_data, tokens)
      steam_account = current_user.steam_account || current_user.build_steam_account

      steam_account.assign_attributes(
        steam_id: user_data[:steam_id],
        persona_name: user_data[:persona_name],
        profile_url: user_data[:profile_url],
        avatar_url: user_data[:avatar_url],
        real_name: user_data[:real_name],
        country_code: user_data[:country_code],
        state_code: user_data[:state_code],
        visibility: user_data[:visibility],
        time_created: user_data[:time_created],
        last_logoff: user_data[:last_logoff],
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        token_expires_at: tokens[:expires_at]
      )

      steam_account.save!
      steam_account
    end

    def privacy_settings_path
      integrations_steam_privacy_settings_path
    end

    def enqueue_sync_job(steam_account)
      SteamSyncJob.perform_later(steam_account.id)
    end

    def privacy_settings_schema
      SteamAccount.privacy_settings_schema
    end

    # Override callback to handle OpenID params
    def callback
      begin
        user_data = fetch_user_data(params)

        # Generate pseudo-tokens for Steam (since it doesn't use OAuth)
        tokens = oauth_service.generate_pseudo_tokens(user_data[:steam_id])

        integration_account = create_or_update_integration_account(user_data, tokens)

        redirect_to privacy_settings_path, notice: 'Steam account connected successfully!'
      rescue Integrations::AuthenticationError => e
        redirect_to settings_path, alert: "Steam authentication failed: #{e.message}"
      rescue Integrations::APIError => e
        redirect_to settings_path, alert: "Failed to connect Steam account: #{e.message}"
      rescue StandardError => e
        Rails.logger.error("Steam callback error: #{e.message}\n#{e.backtrace.join("\n")}")
        redirect_to settings_path, alert: 'An unexpected error occurred. Please try again.'
      end
    end

    def update_privacy_settings
      privacy_setting = @integration_account.integration_privacy_setting

      # Update all settings from form params
      settings_hash = {}
      params[:privacy_settings]&.each do |key, value|
        settings_hash[key] = value == 'true' || value == '1'
      end

      privacy_setting.update!(settings: privacy_setting.settings.merge(settings_hash))

      redirect_to settings_path, notice: 'Steam privacy settings updated successfully!'
    rescue StandardError => e
      redirect_to integrations_steam_privacy_settings_path, alert: "Failed to update settings: #{e.message}"
    end
  end
end
