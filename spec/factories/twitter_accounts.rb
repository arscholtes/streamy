FactoryBot.define do
  factory :twitter_account do
    user { nil }
    twitter_id { "MyString" }
    username { "MyString" }
    name { "MyString" }
    profile_image_url { "MyString" }
    followers_count { 1 }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 05:57:06" }
    last_synced_at { "2025-10-02 05:57:06" }
  end
end
