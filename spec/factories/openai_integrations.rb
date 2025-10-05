FactoryBot.define do
  factory :openai_integration do
    user { nil }
    api_key { "MyString" }
    organization_id { "MyString" }
    usage_limit { 1 }
    usage_count { 1 }
    last_used_at { "2025-10-02 16:26:54" }
  end
end
