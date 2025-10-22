FactoryBot.define do
  factory :chat_timeout do
    user { nil }
    stream { nil }
    timed_out_by_id { 1 }
    reason { "MyText" }
    timed_out_at { "2025-10-17 05:34:40" }
    expires_at { "2025-10-17 05:34:40" }
    duration_seconds { 1 }
    active { false }
  end
end
