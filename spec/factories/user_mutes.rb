FactoryBot.define do
  factory :user_mute do
    association :user
    discord_id { "987654321098765432" }
    moderator_discord_id { "123456789012345678" }
    guild_id { "111222333444555666" }
    reason { "Spamming messages" }
    muted_at { Time.current }
    unmuted_at { nil }
    duration_minutes { 60 }
    active { true }

    trait :expired do
      muted_at { 2.hours.ago }
      duration_minutes { 60 }
      active { true }
    end

    trait :unmuted do
      unmuted_at { 30.minutes.ago }
      active { false }
    end

    trait :short_duration do
      duration_minutes { 5 }
    end

    trait :long_duration do
      duration_minutes { 1440 } # 24 hours
    end
  end
end
