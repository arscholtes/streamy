FactoryBot.define do
  factory :tiktok_account do
    user { nil }
    tiktok_id { "MyString" }
    username { "MyString" }
    display_name { "MyString" }
    follower_count { 1 }
    video_count { 1 }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:30" }
    last_synced_at { "2025-10-02 16:26:30" }
  end
end
