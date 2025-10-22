FactoryBot.define do
  factory :goal_update do
    association :goal
    association :user
    update_type { :progress }
    value_before { 25.0 }
    value_after { 50.0 }
    note { "Made great progress today!" }

    trait :progress do
      update_type { :progress }
      value_before { 25.0 }
      value_after { 50.0 }
    end

    trait :note do
      update_type { :note }
      note { "Important note about this goal" }
      value_before { nil }
      value_after { nil }
    end

    trait :milestone do
      update_type { :milestone }
      value_before { 45.0 }
      value_after { 50.0 }
      note { "Hit 50% milestone!" }
    end

    trait :status_change do
      update_type { :status_change }
      note { "Status changed" }
      value_before { nil }
      value_after { nil }
    end

    trait :big_jump do
      value_before { 20.0 }
      value_after { 80.0 }
    end
  end
end
