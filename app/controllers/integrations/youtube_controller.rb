# app/controllers/integrations/youtube_controller.rb
module Integrations
  class YoutubeController < ApplicationController
    include IntegrationController

    before_action :set_youtube_account, only: [:disconnect, :sync, :update_privacy_settings]

    # Public action for updating privacy settings
    def update_privacy_settings
      privacy_setting = @integration_account.integration_privacy_setting

      settings_hash = {}
      params[:privacy_settings]&.each do |key, value|
        settings_hash[key] = value == 'true' || value == '1'
      end

      privacy_setting.update!(settings: privacy_setting.settings.merge(settings_hash))

      redirect_to settings_path, notice: 'YouTube privacy settings updated successfully!'
    rescue StandardError => e
      redirect_to integrations_youtube_privacy_settings_path, alert: "Failed to update settings: #{e.message}"
    end

    protected

    def oauth_service_class
      Integrations::YoutubeOauthService
    end

    def integration_provider
      :youtube
    end

    def fetch_user_profile(access_token)
      # Create temporary account to use API client
      temp_account = YoutubeAccount.new(access_token: access_token)
      api_client = YoutubeApiClient.new(temp_account)
      channel = api_client.fetch_channel_info

      {
        youtube_id: channel[:id],
        channel_title: channel[:title],
        channel_url: "https://youtube.com/channel/#{channel[:id]}",
        subscriber_count: channel[:subscriber_count],
        video_count: channel[:video_count],
        thumbnail_url: channel[:thumbnail_url]
      }
    end

    private

    def set_youtube_account
      @integration_account = current_user.youtube_account
      redirect_to settings_path, alert: 'YouTube account not connected' unless @integration_account
    end
  end
end
