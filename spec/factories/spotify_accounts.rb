FactoryBot.define do
  factory :spotify_account do
    user { nil }
    spotify_id { "MyString" }
    display_name { "MyString" }
    email { "MyString" }
    product { "MyString" }
    country { "MyString" }
    follower_count { 1 }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:20" }
    last_synced_at { "2025-10-02 16:26:20" }
  end
end
