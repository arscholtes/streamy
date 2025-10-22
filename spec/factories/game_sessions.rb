FactoryBot.define do
  factory :game_session do
    association :user
    stream { nil }
    platform { %w[steam battlenet riot].sample }
    game_name { "Test Game #{rand(1..100)}" }
    game_id { rand(100000..999999).to_s }
    started_at { 2.hours.ago }
    ended_at { nil }
    metadata { { region: "us-west", level: rand(1..100) } }

    trait :active do
      ended_at { nil }
    end

    trait :ended do
      ended_at { 30.minutes.ago }
    end

    trait :steam do
      platform { "steam" }
      game_name { "Counter-Strike 2" }
      game_id { "730" }
    end

    trait :battlenet do
      platform { "battlenet" }
      game_name { "Overwatch 2" }
      game_id { "21298" }
    end

    trait :riot do
      platform { "riot" }
      game_name { "League of Legends" }
      game_id { "league_of_legends" }
    end
  end
end
