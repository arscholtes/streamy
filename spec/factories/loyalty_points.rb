FactoryBot.define do
  factory :loyalty_point do
    user { nil }
    points { 1 }
    level { 1 }
    total_earned { 1 }
    total_spent { 1 }
  end
end
