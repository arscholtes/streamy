FactoryBot.define do
  factory :playstation_account do
    user { nil }
    psn_id { "MyString" }
    online_id { "MyString" }
    account_id { "MyString" }
    region { "MyString" }
    plus_status { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:20" }
    last_synced_at { "2025-10-02 16:26:20" }
  end
end
