FactoryBot.define do
  factory :chat_ban do
    user { nil }
    stream { nil }
    banned_by_id { 1 }
    reason { "MyText" }
    banned_at { "2025-10-17 05:34:39" }
    expires_at { "2025-10-17 05:34:39" }
    permanent { false }
    active { false }
  end
end
