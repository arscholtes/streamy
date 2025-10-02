FactoryBot.define do
  factory :youtube_account do
    user { nil }
    youtube_id { "MyString" }
    channel_title { "MyString" }
    channel_url { "MyString" }
    subscriber_count { 1 }
    video_count { 1 }
    thumbnail_url { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 05:57:06" }
    last_synced_at { "2025-10-02 05:57:06" }
  end
end
