FactoryBot.define do
  factory :achievement do
    name { "MyString" }
    description { "MyText" }
    icon { "MyString" }
    category { "MyString" }
    points_reward { 1 }
    requirement_type { "MyString" }
    requirement_value { 1 }
  end
end
