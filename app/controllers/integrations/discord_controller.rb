# app/controllers/integrations/discord_controller.rb
module Integrations
  class DiscordController < ApplicationController
    include IntegrationController

    before_action :set_discord_account, only: [:disconnect, :sync, :privacy_settings, :update_privacy_settings]

    private

    def set_discord_account
      @integration_account = current_user.discord_account
      redirect_to settings_path, alert: 'Discord account not connected' unless @integration_account
    end

    def oauth_service
      @oauth_service ||= DiscordOauthService.new
    end

    def oauth_authorize_url
      oauth_service.authorize_url
    end

    def fetch_user_data(access_token)
      oauth_service.fetch_user_data(access_token)
    end

    def create_or_update_integration_account(user_data, tokens)
      discord_account = current_user.discord_account || current_user.build_discord_account

      discord_account.assign_attributes(
        discord_id: user_data[:discord_id],
        username: user_data[:username],
        discriminator: user_data[:discriminator],
        avatar_url: user_data[:avatar_url],
        email: user_data[:email],
        verified: user_data[:verified],
        locale: user_data[:locale],
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        token_expires_at: tokens[:expires_at]
      )

      discord_account.save!
      discord_account
    end

    def privacy_settings_path
      integrations_discord_privacy_settings_path
    end

    def enqueue_sync_job(discord_account)
      DiscordSyncJob.perform_later(discord_account.id)
    end

    def privacy_settings_schema
      DiscordAccount.privacy_settings_schema
    end

    def update_privacy_settings
      privacy_setting = @integration_account.integration_privacy_setting

      settings_hash = {}
      params[:privacy_settings]&.each do |key, value|
        settings_hash[key] = value == 'true' || value == '1'
      end

      privacy_setting.update!(settings: privacy_setting.settings.merge(settings_hash))

      redirect_to settings_path, notice: 'Discord privacy settings updated successfully!'
    rescue StandardError => e
      redirect_to integrations_discord_privacy_settings_path, alert: "Failed to update settings: #{e.message}"
    end
  end
end
