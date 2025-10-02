FactoryBot.define do
  factory :payment do
    user { nil }
    stripe_payment_intent_id { "MyString" }
    stripe_charge_id { "MyString" }
    amount_cents { 1 }
    currency { "MyString" }
    status { "MyString" }
    payment_type { "MyString" }
    description { "MyText" }
    metadata { "" }
  end
end
