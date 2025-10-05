FactoryBot.define do
  factory :epic_account do
    user { nil }
    epic_id { "MyString" }
    display_name { "MyString" }
    email { "MyString" }
    country { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:25:41" }
    last_synced_at { "2025-10-02 16:25:41" }
  end
end
