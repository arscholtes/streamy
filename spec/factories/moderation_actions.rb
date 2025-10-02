FactoryBot.define do
  factory :moderation_action do
    association :user
    action_type { 'warn' }
    target_user_id { nil }
    moderator_discord_id { "123456789012345678" }
    target_discord_id { "987654321098765432" }
    reason { "Test moderation action" }
    metadata { {} }
    guild_id { "111222333444555666" }
    performed_at { Time.current }

    trait :warn do
      action_type { 'warn' }
    end

    trait :mute do
      action_type { 'mute' }
    end

    trait :kick do
      action_type { 'kick' }
    end

    trait :ban do
      action_type { 'ban' }
    end
  end
end
