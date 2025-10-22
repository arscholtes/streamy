FactoryBot.define do
  factory :goal_step do
    association :goal
    sequence(:title) { |n| "Step #{n}: Complete this task" }
    sequence(:position) { |n| n }
    completed { false }

    trait :completed do
      completed { true }
    end

    trait :pending do
      completed { false }
    end

    trait :first do
      position { 0 }
      title { "First step in the journey" }
    end

    trait :last do
      position { 10 }
      title { "Final step to completion" }
    end
  end
end
