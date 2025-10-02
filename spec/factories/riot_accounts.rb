FactoryBot.define do
  factory :riot_account do
    user { nil }
    puuid { "MyString" }
    game_name { "MyString" }
    tag_line { "MyString" }
    region { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 05:56:56" }
    last_synced_at { "2025-10-02 05:56:56" }
  end
end
