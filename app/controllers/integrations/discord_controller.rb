# app/controllers/integrations/discord_controller.rb
module Integrations
  class DiscordController < ApplicationController
    include IntegrationController

    before_action :set_discord_account, only: [:disconnect, :sync, :update_privacy_settings]

    # Public action for updating privacy settings
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

    protected

    def oauth_service_class
      Integrations::DiscordOauthService
    end

    def integration_provider
      :discord
    end

    def fetch_user_profile(access_token)
      # Create temporary account to use API client
      temp_account = DiscordAccount.new(access_token: access_token)
      api_client = DiscordApiClient.new(temp_account)
      user = api_client.fetch_user_profile

      {
        discord_id: user[:id],
        username: user[:username],
        discriminator: user[:discriminator],
        avatar_url: user[:avatar] ? "https://cdn.discordapp.com/avatars/#{user[:id]}/#{user[:avatar]}.png" : nil,
        email: user[:email],
        verified: user[:verified],
        locale: user[:locale]
      }
    end

    private

    def set_discord_account
      @integration_account = current_user.discord_account
      redirect_to settings_path, alert: 'Discord account not connected' unless @integration_account
    end
  end
end
