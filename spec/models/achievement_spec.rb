require 'rails_helper'

RSpec.describe Achievement, type: :model do
  describe 'associations' do
    it { should have_many(:user_achievements).dependent(:destroy) }
    it { should have_many(:users).through(:user_achievements) }
  end

  describe 'validations' do
    subject { build(:achievement) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:category) }
    it { should validate_presence_of(:points_reward) }
    it { should validate_numericality_of(:points_reward).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:requirement_type) }
    it { should validate_presence_of(:requirement_value) }
    it { should validate_numericality_of(:requirement_value).is_greater_than(0) }
    it { should validate_inclusion_of(:category).in_array(Achievement::CATEGORIES) }
    it { should validate_inclusion_of(:requirement_type).in_array(Achievement::REQUIREMENT_TYPES) }
  end

  describe 'scopes' do
    let!(:streaming_achievement) { create(:achievement, category: 'streaming', points_reward: 100) }
    let!(:gaming_achievement) { create(:achievement, category: 'gaming', points_reward: 50) }

    describe '.by_category' do
      it 'returns achievements for a specific category' do
        expect(Achievement.by_category('streaming')).to include(streaming_achievement)
        expect(Achievement.by_category('streaming')).not_to include(gaming_achievement)
      end
    end

    describe '.ordered' do
      it 'orders achievements by category and points_reward' do
        expect(Achievement.ordered).to eq([gaming_achievement, streaming_achievement])
      end
    end
  end

  describe 'constants' do
    it 'has CATEGORIES' do
      expect(Achievement::CATEGORIES).to match_array(%w[streaming social gaming community milestones special])
    end

    it 'has REQUIREMENT_TYPES' do
      expect(Achievement::REQUIREMENT_TYPES).to match_array(%w[total_stream_hours total_viewers follower_count subscriber_count points_earned games_played custom])
    end
  end

  describe '#award_to' do
    let(:user) { create(:user) }
    let(:achievement) { create(:achievement, points_reward: 100) }

    context 'when user does not have the achievement' do
      it 'creates a user_achievement' do
        expect {
          achievement.award_to(user)
        }.to change { user.user_achievements.count }.by(1)
      end

      it 'awards loyalty points to the user' do
        user.create_loyalty_point!(points: 0, level: 1, total_earned: 0, total_spent: 0)

        expect {
          achievement.award_to(user)
        }.to change { user.loyalty_point.reload.points }.by(achievement.points_reward)
      end

      it 'creates loyalty points if user does not have any' do
        expect(user.loyalty_point).to be_nil
        achievement.award_to(user)
        expect(user.reload.loyalty_point).to be_present
      end

      it 'returns the user_achievement' do
        result = achievement.award_to(user)
        expect(result).to be_a(UserAchievement)
        expect(result.achievement).to eq(achievement)
        expect(result.user).to eq(user)
      end
    end

    context 'when user already has the achievement' do
      before do
        create(:user_achievement, user: user, achievement: achievement)
      end

      it 'does not create a duplicate user_achievement' do
        expect {
          achievement.award_to(user)
        }.not_to change { user.user_achievements.count }
      end

      it 'returns false' do
        expect(achievement.award_to(user)).to be false
      end
    end
  end
end
