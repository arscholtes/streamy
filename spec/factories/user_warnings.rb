FactoryBot.define do
  factory :user_warning do
    association :user
    discord_id { "987654321098765432" }
    moderator_discord_id { "123456789012345678" }
    guild_id { "111222333444555666" }
    reason { "Spamming in chat" }
    warned_at { Time.current }

    trait :old do
      warned_at { 45.days.ago }
    end

    trait :recent do
      warned_at { 1.day.ago }
    end
  end
end
