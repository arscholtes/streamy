FactoryBot.define do
  factory :moderator_role do
    stream { nil }
    name { "MyString" }
    can_timeout_users { false }
    can_ban_users { false }
    can_delete_messages { false }
    can_manage_slow_mode { false }
    can_manage_emote_only { false }
    can_manage_moderators { false }
    description { "MyText" }
  end
end
