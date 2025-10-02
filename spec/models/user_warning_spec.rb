require 'rails_helper'

RSpec.describe UserWarning, type: :model do
  describe 'associations' do
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:discord_id) }
    it { should validate_presence_of(:moderator_discord_id) }
    it { should validate_presence_of(:guild_id) }
    it { should validate_presence_of(:warned_at) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:discord_id) { "123456789" }
    let(:guild_id) { "111222333" }
    let!(:old_warning) { create(:user_warning, :old, user: user, discord_id: discord_id, guild_id: guild_id) }
    let!(:active_warning) { create(:user_warning, user: user, discord_id: discord_id, guild_id: guild_id, warned_at: 1.day.ago) }
    let!(:most_recent_warning) { create(:user_warning, user: user, discord_id: "999999999", guild_id: guild_id) }

    it 'filters by guild' do
      expect(UserWarning.for_guild(guild_id)).to include(active_warning, old_warning, most_recent_warning)
    end

    it 'filters by user' do
      expect(UserWarning.for_user(discord_id)).to include(active_warning, old_warning)
      expect(UserWarning.for_user(discord_id)).not_to include(most_recent_warning)
    end

    it 'orders by most recent' do
      expect(UserWarning.recent.first).to eq(most_recent_warning)
    end

    it 'filters active warnings (within 30 days)' do
      expect(UserWarning.active).to include(active_warning, most_recent_warning)
      expect(UserWarning.active).not_to include(old_warning)
    end
  end

  describe '.count_for_user' do
    let(:user) { create(:user) }
    let(:discord_id) { "123456789" }
    let(:guild_id) { "111222333" }

    it 'counts active warnings for a user' do
      create_list(:user_warning, 3, user: user, discord_id: discord_id, guild_id: guild_id)
      create(:user_warning, :old, user: user, discord_id: discord_id, guild_id: guild_id)

      expect(UserWarning.count_for_user(discord_id, guild_id)).to eq(3)
    end
  end

  describe '.recent_for_user' do
    let(:user) { create(:user) }
    let(:discord_id) { "123456789" }
    let(:guild_id) { "111222333" }

    it 'returns recent warnings with limit' do
      create_list(:user_warning, 10, user: user, discord_id: discord_id, guild_id: guild_id)

      result = UserWarning.recent_for_user(discord_id, guild_id, 5)
      expect(result.count).to eq(5)
    end
  end

  describe '.clear_for_user' do
    let(:user) { create(:user) }
    let(:discord_id) { "123456789" }
    let(:guild_id) { "111222333" }

    it 'deletes all warnings for a user in a guild' do
      create_list(:user_warning, 3, user: user, discord_id: discord_id, guild_id: guild_id)
      other_warning = create(:user_warning, user: user, discord_id: "999999999", guild_id: guild_id)

      expect {
        UserWarning.clear_for_user(discord_id, guild_id)
      }.to change { UserWarning.for_user(discord_id).for_guild(guild_id).count }.from(3).to(0)

      expect(UserWarning.find_by(id: other_warning.id)).to be_present
    end
  end
end
