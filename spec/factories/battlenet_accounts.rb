FactoryBot.define do
  factory :battlenet_account do
    user { nil }
    battletag { "MyString" }
    region { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 05:56:44" }
    last_synced_at { "2025-10-02 05:56:44" }
  end
end
