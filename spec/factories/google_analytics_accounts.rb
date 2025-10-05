FactoryBot.define do
  factory :google_analytics_account do
    user { nil }
    property_id { "MyString" }
    account_id { "MyString" }
    property_name { "MyString" }
    tracking_id { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:54" }
    last_synced_at { "2025-10-02 16:26:54" }
  end
end
