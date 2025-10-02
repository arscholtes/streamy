FactoryBot.define do
  factory :discord_account do
    user { nil }
    discord_id { "MyString" }
    username { "MyString" }
    discriminator { "MyString" }
    avatar_url { "MyString" }
    email { "MyString" }
    verified { false }
    locale { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 05:54:02" }
    last_synced_at { "2025-10-02 05:54:02" }
  end
end
