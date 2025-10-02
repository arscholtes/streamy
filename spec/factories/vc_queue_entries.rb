FactoryBot.define do
  factory :vc_queue_entry do
    user { nil }
    discord_user_id { "MyString" }
    priority { 1 }
    position { 1 }
    status { "MyString" }
    joined_at { "2025-10-02 06:12:50" }
    left_at { "2025-10-02 06:12:50" }
  end
end
