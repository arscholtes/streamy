FactoryBot.define do
  factory :video do
    user { nil }
    title { "MyString" }
    description { "MyText" }
    video_url { "MyString" }
    thumbnail_url { "MyString" }
    duration_seconds { 1 }
    view_count { 1 }
    status { "MyString" }
  end
end
