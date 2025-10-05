FactoryBot.define do
  factory :instagram_account do
    user { nil }
    instagram_id { "MyString" }
    username { "MyString" }
    full_name { "MyString" }
    follower_count { 1 }
    media_count { 1 }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:31" }
    last_synced_at { "2025-10-02 16:26:31" }
  end
end
