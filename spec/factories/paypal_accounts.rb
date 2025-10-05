FactoryBot.define do
  factory :paypal_account do
    user { nil }
    paypal_id { "MyString" }
    email { "MyString" }
    verified { false }
    account_type { "MyString" }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 16:26:42" }
    last_synced_at { "2025-10-02 16:26:42" }
  end
end
