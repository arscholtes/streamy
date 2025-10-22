FactoryBot.define do
  factory :youtube_account do
    association :user

    youtube_id { "UC#{SecureRandom.alphanumeric(22)}" }
    channel_title { "#{Faker::Internet.username.capitalize} Gaming" }
    channel_url { "https://youtube.com/channel/#{youtube_id}" }
    subscriber_count { rand(100..100000) }
    video_count { rand(10..500) }
    thumbnail_url { "https://yt3.ggpht.com/#{SecureRandom.alphanumeric(32)}" }
    access_token { SecureRandom.urlsafe_base64(64) }
    refresh_token { SecureRandom.urlsafe_base64(64) }
    token_expires_at { 1.hour.from_now }
    last_synced_at { 1.hour.ago }

    trait :with_large_following do
      subscriber_count { rand(100_000..1_000_000) }
      video_count { rand(500..2000) }
    end

    trait :new_channel do
      subscriber_count { rand(1..100) }
      video_count { rand(1..10) }
    end

    trait :expired_token do
      token_expires_at { 1.day.ago }
    end

    trait :needs_sync do
      last_synced_at { 2.days.ago }
    end

    trait :recently_synced do
      last_synced_at { 5.minutes.ago }
    end
  end
end
