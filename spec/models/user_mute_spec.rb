require 'rails_helper'

RSpec.describe UserMute, type: :model do
  describe 'associations' do
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:discord_id) }
    it { should validate_presence_of(:moderator_discord_id) }
    it { should validate_presence_of(:guild_id) }
    it { should validate_presence_of(:muted_at) }
    it { should validate_presence_of(:duration_minutes) }
    it { should validate_numericality_of(:duration_minutes).is_greater_than(0) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:discord_id) { "123456789" }
    let(:guild_id) { "111222333" }
    let!(:active_mute) { create(:user_mute, user: user, discord_id: discord_id, guild_id: guild_id) }
    let!(:expired_mute) { create(:user_mute, :expired, user: user, discord_id: discord_id, guild_id: guild_id) }
    let!(:unmuted) { create(:user_mute, :unmuted, user: user, discord_id: "999999999", guild_id: guild_id) }

    it 'filters by guild' do
      expect(UserMute.for_guild(guild_id)).to include(active_mute, expired_mute, unmuted)
    end

    it 'filters by user' do
      expect(UserMute.for_user(discord_id)).to include(active_mute, expired_mute)
      expect(UserMute.for_user(discord_id)).not_to include(unmuted)
    end

    it 'filters active mutes' do
      expect(UserMute.active_mutes).to include(active_mute, expired_mute)
      expect(UserMute.active_mutes).not_to include(unmuted)
    end

    it 'filters expired mutes' do
      expect(UserMute.expired).to include(expired_mute)
      expect(UserMute.expired).not_to include(active_mute)
    end

    it 'orders by most recent' do
      expect(UserMute.recent.first).to eq(unmuted)
    end
  end

  describe '#ends_at' do
    let(:mute) { create(:user_mute, muted_at: Time.current, duration_minutes: 60) }

    it 'calculates the end time correctly' do
      expect(mute.ends_at).to be_within(1.second).of(Time.current + 60.minutes)
    end
  end

  describe '#expired?' do
    it 'returns true for expired mutes' do
      mute = create(:user_mute, :expired)
      expect(mute.expired?).to be true
    end

    it 'returns false for active mutes' do
      mute = create(:user_mute, muted_at: Time.current, duration_minutes: 60)
      expect(mute.expired?).to be false
    end
  end

  describe '#time_remaining' do
    it 'returns 0 for expired mutes' do
      mute = create(:user_mute, :expired)
      expect(mute.time_remaining).to eq(0)
    end

    it 'returns time remaining in minutes' do
      mute = create(:user_mute, muted_at: Time.current, duration_minutes: 60)
      expect(mute.time_remaining).to be_within(1).of(60)
    end
  end

  describe '#unmute!' do
    let(:mute) { create(:user_mute, active: true) }

    it 'marks the mute as inactive' do
      mute.unmute!
      expect(mute.active).to be false
    end

    it 'sets unmuted_at timestamp' do
      mute.unmute!
      expect(mute.unmuted_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '.active_for_user' do
    let(:user) { create(:user) }
    let(:discord_id) { "123456789" }
    let(:guild_id) { "111222333" }

    it 'returns active non-expired mute for user' do
      active_mute = create(:user_mute, user: user, discord_id: discord_id, guild_id: guild_id, muted_at: Time.current, duration_minutes: 60)
      create(:user_mute, :expired, user: user, discord_id: discord_id, guild_id: guild_id)

      result = UserMute.active_for_user(discord_id, guild_id)
      expect(result).to eq(active_mute)
    end

    it 'returns nil if no active mute exists' do
      create(:user_mute, :expired, user: user, discord_id: discord_id, guild_id: guild_id)

      result = UserMute.active_for_user(discord_id, guild_id)
      expect(result).to be_nil
    end
  end

  describe '.check_and_expire_mutes' do
    it 'unmutes expired mutes' do
      expired_mute = create(:user_mute, :expired, active: true)
      active_mute = create(:user_mute, muted_at: Time.current, duration_minutes: 60, active: true)

      UserMute.check_and_expire_mutes

      expect(expired_mute.reload.active).to be false
      expect(active_mute.reload.active).to be true
    end
  end
end
