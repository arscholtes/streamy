require 'rails_helper'

RSpec.describe ModerationAction, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:action_type) }
    it { should validate_presence_of(:moderator_discord_id) }
    it { should validate_presence_of(:target_discord_id) }
    it { should validate_presence_of(:guild_id) }
    it { should validate_presence_of(:performed_at) }
    it { should validate_inclusion_of(:action_type).in_array(ModerationAction::ACTION_TYPES) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:guild_id) { "123456789" }
    let!(:warn_action) { create(:moderation_action, :warn, user: user, guild_id: guild_id) }
    let!(:mute_action) { create(:moderation_action, :mute, user: user, guild_id: guild_id) }
    let!(:other_guild_action) { create(:moderation_action, user: user, guild_id: "999999999") }

    it 'filters by guild' do
      expect(ModerationAction.for_guild(guild_id)).to include(warn_action, mute_action)
      expect(ModerationAction.for_guild(guild_id)).not_to include(other_guild_action)
    end

    it 'filters by target' do
      target_id = warn_action.target_discord_id
      expect(ModerationAction.for_target(target_id)).to include(warn_action)
    end

    it 'filters by action type' do
      expect(ModerationAction.by_type('warn')).to include(warn_action)
      expect(ModerationAction.by_type('warn')).not_to include(mute_action)
    end

    it 'orders by most recent' do
      expect(ModerationAction.recent.first).to eq(other_guild_action)
    end
  end

  describe '.log_action' do
    let(:user) { create(:user) }

    it 'creates a moderation action' do
      expect {
        ModerationAction.log_action(
          action_type: 'warn',
          moderator_discord_id: '123456',
          target_discord_id: '789012',
          guild_id: '111222',
          user: user,
          reason: 'Test reason'
        )
      }.to change(ModerationAction, :count).by(1)
    end

    it 'sets performed_at to current time' do
      action = ModerationAction.log_action(
        action_type: 'kick',
        moderator_discord_id: '123456',
        target_discord_id: '789012',
        guild_id: '111222',
        user: user
      )

      expect(action.performed_at).to be_within(1.second).of(Time.current)
    end
  end
end
