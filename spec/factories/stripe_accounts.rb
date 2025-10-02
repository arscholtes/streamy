FactoryBot.define do
  factory :stripe_account do
    user { nil }
    stripe_id { "MyString" }
    email { "MyString" }
    account_type { "MyString" }
    charges_enabled { false }
    payouts_enabled { false }
    access_token { "MyString" }
    refresh_token { "MyString" }
    token_expires_at { "2025-10-02 05:57:18" }
    last_synced_at { "2025-10-02 05:57:18" }
  end
end
