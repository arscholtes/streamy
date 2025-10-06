FactoryBot.define do
  factory :mini_game_session do
    association :user
    game_type { 'coinflip' }
    bet_amount { 10 }
    result { 'win' }
    winnings { 20 }
    metadata { {} }
    played_at { Time.current }

    trait :win do
      result { 'win' }
      winnings { bet_amount * 2 }
    end

    trait :loss do
      result { 'loss' }
      winnings { 0 }
    end

    trait :draw do
      result { 'draw' }
      winnings { bet_amount }
    end

    trait :coinflip do
      game_type { 'coinflip' }
    end

    trait :roulette do
      game_type { 'roulette' }
    end

    trait :slots do
      game_type { 'slots' }
    end

    trait :trivia do
      game_type { 'trivia' }
    end

    trait :duel do
      game_type { 'duel' }
    end
  end
end
