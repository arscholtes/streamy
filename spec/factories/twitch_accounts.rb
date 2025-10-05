FactoryBot.define do
  factory :twitch_account do
    user { nil }
    twitch_id { "MyString" }
    login { "MyString" }
    display_name { "MyString" }
    broadcaster_type { "MyString" }
    description { "MyString" }
    profile_image_url { "MyString" }
    view_count { 1 }
    follower_count { 1 }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:41" }
    last_synced_at { "2025-10-02 16:26:41" }
  end
end
