FactoryBot.define do
  factory :follow do
    follower { nil }
    followee { nil }
    notifications_enabled { false }
  end
end
