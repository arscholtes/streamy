# app/models/youtube_account.rb
class YoutubeAccount < ApplicationRecord
  include IntegrationAccount

  alias_attribute :external_id, :youtube_id

  has_many :videos, dependent: :nullify

  validates :youtube_id, presence: true, uniqueness: true
  validates :channel_title, presence: true

  def oauth_service_class
    Integrations::YoutubeOauthService
  end

  def sync_service_class
    Integrations::YoutubeSyncService
  end

  def self.privacy_settings_schema
    {
      profile: [
        { key: 'show_channel_link', label: 'Show YouTube channel link', default: true },
        { key: 'show_subscriber_count', label: 'Show subscriber count', default: true },
        { key: 'show_video_count', label: 'Show video count', default: true }
      ],
      content: [
        { key: 'show_recent_videos', label: 'Show recent videos', default: true },
        { key: 'auto_upload_highlights', label: 'Auto-upload stream highlights', default: false }
      ]
    }
  end

  def default_privacy_settings
    {
      show_channel_link: true,
      show_subscriber_count: true,
      show_video_count: true,
      show_recent_videos: true,
      auto_upload_highlights: false
    }
  end
end
