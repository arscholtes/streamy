require 'rails_helper'

RSpec.describe UserAchievement, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:achievement) }
  end

  describe 'validations' do
    subject { build(:user_achievement) }

    it { should validate_uniqueness_of(:user_id).scoped_to(:achievement_id) }
    it { should validate_presence_of(:progress) }
    it { should validate_numericality_of(:progress).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:achievement) { create(:achievement) }
    let!(:earned_achievement) { create(:user_achievement, user: user, achievement: achievement, earned_at: 1.day.ago) }
    let!(:in_progress_achievement) { create(:user_achievement, user: user, achievement: create(:achievement), earned_at: nil) }

    describe '.earned' do
      it 'returns only earned achievements' do
        expect(UserAchievement.earned).to include(earned_achievement)
        expect(UserAchievement.earned).not_to include(in_progress_achievement)
      end
    end

    describe '.in_progress' do
      it 'returns only in-progress achievements' do
        expect(UserAchievement.in_progress).to include(in_progress_achievement)
        expect(UserAchievement.in_progress).not_to include(earned_achievement)
      end
    end

    describe '.recent' do
      it 'returns earned achievements ordered by most recent' do
        older_achievement = create(:user_achievement, user: user, achievement: create(:achievement), earned_at: 2.days.ago)
        expect(UserAchievement.recent(10).first).to eq(earned_achievement)
      end

      it 'limits the results to the specified number' do
        3.times { create(:user_achievement, user: user, achievement: create(:achievement), earned_at: Time.current) }
        expect(UserAchievement.recent(2).count).to eq(2)
      end
    end
  end

  describe '#earned?' do
    it 'returns true when earned_at is present' do
      user_achievement = build(:user_achievement, earned_at: Time.current)
      expect(user_achievement.earned?).to be true
    end

    it 'returns false when earned_at is nil' do
      user_achievement = build(:user_achievement, earned_at: nil)
      expect(user_achievement.earned?).to be false
    end
  end

  describe '#progress_percentage' do
    let(:achievement) { create(:achievement, requirement_value: 100) }

    it 'returns 100 when achievement is earned' do
      user_achievement = build(:user_achievement, achievement: achievement, earned_at: Time.current, progress: 100)
      expect(user_achievement.progress_percentage).to eq(100)
    end

    it 'calculates percentage correctly when in progress' do
      user_achievement = build(:user_achievement, achievement: achievement, earned_at: nil, progress: 50)
      expect(user_achievement.progress_percentage).to eq(50.0)
    end

    it 'returns 0 when requirement_value is zero' do
      achievement.update(requirement_value: 0)
      user_achievement = build(:user_achievement, achievement: achievement, earned_at: nil, progress: 0)
      expect(user_achievement.progress_percentage).to eq(0)
    end
  end

  describe '#update_progress' do
    let(:user) { create(:user) }
    let(:achievement) { create(:achievement, requirement_value: 100, points_reward: 50) }
    let(:user_achievement) { create(:user_achievement, user: user, achievement: achievement, progress: 50, earned_at: nil) }

    context 'when achievement is not yet earned' do
      it 'updates the progress' do
        user_achievement.update_progress(75)
        expect(user_achievement.reload.progress).to eq(75)
      end

      it 'completes the achievement when progress reaches requirement' do
        user.create_loyalty_point!(points: 0, level: 1, total_earned: 0, total_spent: 0)
        user_achievement.update_progress(100)
        expect(user_achievement.reload.earned?).to be true
      end
    end

    context 'when achievement is already earned' do
      before { user_achievement.update(earned_at: Time.current) }

      it 'does not update progress' do
        expect {
          user_achievement.update_progress(75)
        }.not_to change { user_achievement.reload.progress }
      end
    end
  end
end
