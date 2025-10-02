# app/models/twitter_account.rb
class TwitterAccount < ApplicationRecord
  include IntegrationAccount

  alias_attribute :external_id, :twitter_id

  validates :twitter_id, presence: true, uniqueness: true
  validates :username, presence: true

  def oauth_service_class
    Integrations::TwitterOauthService
  end

  def sync_service_class
    Integrations::TwitterSyncService
  end

  def self.privacy_settings_schema
    {
      profile: [
        { key: 'show_twitter_handle', label: 'Show Twitter handle', default: true },
        { key: 'show_followers_count', label: 'Show followers count', default: true },
        { key: 'show_profile_image', label: 'Show profile image', default: true }
      ],
      activity: [
        { key: 'show_recent_tweets', label: 'Show recent tweets', default: true },
        { key: 'auto_post_clips', label: 'Auto-post stream clips to Twitter', default: false }
      ]
    }
  end
end
