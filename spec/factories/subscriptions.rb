FactoryBot.define do
  factory :subscription do
    user { nil }
    stripe_subscription_id { "MyString" }
    stripe_customer_id { "MyString" }
    status { "MyString" }
    plan { "MyString" }
    current_period_start { "2025-10-02 10:13:50" }
    current_period_end { "2025-10-02 10:13:50" }
    cancel_at_period_end { false }
  end
end
