FactoryBot.define do
  factory :stream_moderator do
    user { nil }
    stream { nil }
    moderator_role { nil }
    appointed_at { "2025-10-17 05:32:53" }
    appointed_by_id { 1 }
    active { false }
  end
end
