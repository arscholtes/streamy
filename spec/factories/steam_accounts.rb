FactoryBot.define do
  factory :steam_account do
    user { nil }
    steam_id { "MyString" }
    persona_name { "MyString" }
    profile_url { "MyString" }
    avatar_url { "MyString" }
    real_name { "MyString" }
    country_code { "MyString" }
    state_code { "MyString" }
    visibility { 1 }
    time_created { 1 }
    last_logoff { 1 }
    level { 1 }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 05:47:13" }
    last_synced_at { "2025-10-02 05:47:13" }
  end
end
