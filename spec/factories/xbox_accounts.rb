FactoryBot.define do
  factory :xbox_account do
    user { nil }
    xbox_id { "MyString" }
    gamertag { "MyString" }
    gamerscore { 1 }
    account_tier { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:19" }
    last_synced_at { "2025-10-02 16:26:19" }
  end
end
