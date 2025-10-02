FactoryBot.define do
  factory :chat_message do
    user { nil }
    stream { nil }
    content { "MyText" }
  end
end
