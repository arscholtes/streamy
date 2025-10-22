# app/services/integrations/youtube_sync_service.rb
# Syncs YouTube channel data
module Integrations
  class YoutubeSyncService
    attr_reader :youtube_account

    def initialize(youtube_account)
      @youtube_account = youtube_account
      @api_client = YoutubeApiClient.new(youtube_account)
    end

    def sync!
      ActiveRecord::Base.transaction do
        sync_channel_info
      end

      youtube_account.update!(last_synced_at: Time.current)
    rescue Integrations::APIError => e
      Rails.logger.error("YouTube sync failed for account #{youtube_account.id}: #{e.message}")
      raise
    end

    private

    def sync_channel_info
      channel_data = @api_client.fetch_channel_info

      return unless channel_data

      youtube_account.update!(
        youtube_id: channel_data[:id],
        channel_title: channel_data[:title],
        channel_url: "https://youtube.com/channel/#{channel_data[:id]}",
        subscriber_count: channel_data[:subscriber_count],
        video_count: channel_data[:video_count],
        thumbnail_url: channel_data[:thumbnail_url]
      )
    end
  end
end
