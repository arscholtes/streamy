FactoryBot.define do
  factory :subscription do
    association :user
    sequence(:stripe_subscription_id) { |n| "sub_test#{n}" }
    sequence(:stripe_customer_id) { |n| "cus_test#{n}" }
    status { "active" }
    plan { "pro" }
    current_period_start { 1.month.ago }
    current_period_end { 1.month.from_now }
    cancel_at_period_end { false }

    trait :trialing do
      status { "trialing" }
    end

    trait :canceled do
      status { "canceled" }
      canceled_at { 1.day.ago }
    end

    trait :past_due do
      status { "past_due" }
    end

    trait :free_plan do
      plan { "free" }
    end

    trait :enterprise_plan do
      plan { "enterprise" }
    end

    trait :cancel_at_period_end do
      cancel_at_period_end { true }
    end
  end
end
