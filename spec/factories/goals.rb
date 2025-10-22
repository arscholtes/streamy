FactoryBot.define do
  factory :goal do
    association :user
    title { "Reach 500 followers" }
    description { "Grow my audience to 500 followers by the end of the quarter" }
    goal_type { :growth }
    status { :active }
    progress_type { :percentage }
    current_value { 0.0 }
    target_value { 100.0 }
    deadline { 3.months.from_now }
    started_at { Time.current }
    completed_at { nil }
    visibility { :private_goal }
    metadata { {} }

    # Traits for different goal types
    trait :growth do
      goal_type { :growth }
      title { "Reach 500 followers" }
    end

    trait :content do
      goal_type { :content }
      title { "Stream 3 times per week" }
    end

    trait :skill do
      goal_type { :skill }
      title { "Reach Diamond rank" }
    end

    trait :business do
      goal_type { :business }
      title { "Earn $1000/month" }
    end

    trait :community do
      goal_type { :community }
      title { "Get 100 Discord members" }
    end

    trait :personal do
      goal_type { :personal }
      title { "Take 1 day off per week" }
    end

    # Traits for different statuses
    trait :draft do
      status { :draft }
      started_at { nil }
    end

    trait :active do
      status { :active }
      started_at { Time.current }
    end

    trait :paused do
      status { :paused }
      started_at { 1.month.ago }
    end

    trait :completed do
      status { :completed }
      current_value { 100.0 }
      started_at { 2.months.ago }
      completed_at { Time.current }
    end

    trait :abandoned do
      status { :abandoned }
      started_at { 2.months.ago }
    end

    trait :failed do
      status { :failed }
      deadline { 1.week.ago }
    end

    # Progress traits
    trait :halfway do
      current_value { 50.0 }
    end

    trait :almost_done do
      current_value { 90.0 }
    end

    trait :overdue do
      deadline { 1.week.ago }
      current_value { 30.0 }
    end

    trait :on_track do
      started_at { 1.month.ago }
      deadline { 2.months.from_now }
      current_value { 33.0 }
    end

    trait :public_goal do
      visibility { :public_goal }
    end

    trait :with_steps do
      after(:create) do |goal|
        create_list(:goal_step, 3, goal: goal)
      end
    end

    trait :with_updates do
      after(:create) do |goal|
        create_list(:goal_update, 5, goal: goal, user: goal.user)
      end
    end
  end
end
