require 'rails_helper'

RSpec.describe GoalUpdate, type: :model do
  describe 'associations' do
    it { should belong_to(:goal) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:update_type) }
  end

  describe 'enums' do
    it { should define_enum_for(:update_type).with_values(progress: 0, note: 1, milestone: 2, status_change: 3) }
  end

  describe 'scopes' do
    let(:goal) { create(:goal) }
    let!(:old_update) { create(:goal_update, goal: goal, created_at: 2.days.ago) }
    let!(:new_update) { create(:goal_update, goal: goal, created_at: 1.day.ago) }

    it 'orders by most recent' do
      expect(GoalUpdate.recent.first).to eq(new_update)
    end

    it 'filters by goal' do
      other_goal = create(:goal)
      other_update = create(:goal_update, goal: other_goal)

      expect(GoalUpdate.for_goal(goal.id)).to include(old_update, new_update)
      expect(GoalUpdate.for_goal(goal.id)).not_to include(other_update)
    end
  end

  describe '#progress_delta' do
    it 'calculates the difference between values' do
      update = create(:goal_update, value_before: 25, value_after: 50)
      expect(update.progress_delta).to eq(25)
    end

    it 'returns nil when values are nil' do
      update = create(:goal_update, value_before: nil, value_after: nil)
      expect(update.progress_delta).to be_nil
    end

    it 'handles negative progress' do
      update = create(:goal_update, value_before: 50, value_after: 25)
      expect(update.progress_delta).to eq(-25)
    end
  end

  describe '#progress_delta_percentage' do
    it 'calculates percentage change' do
      update = create(:goal_update, value_before: 25, value_after: 50)
      expect(update.progress_delta_percentage).to eq(100.0)
    end

    it 'returns nil when values are nil' do
      update = create(:goal_update, value_before: nil, value_after: nil)
      expect(update.progress_delta_percentage).to be_nil
    end

    it 'returns nil when value_before is zero' do
      update = create(:goal_update, value_before: 0, value_after: 50)
      expect(update.progress_delta_percentage).to be_nil
    end

    it 'handles negative percentage change' do
      update = create(:goal_update, value_before: 100, value_after: 75)
      expect(update.progress_delta_percentage).to eq(-25.0)
    end
  end

  describe 'update types' do
    it 'creates progress update' do
      update = create(:goal_update, :progress)
      expect(update.progress?).to be true
    end

    it 'creates note update' do
      update = create(:goal_update, :note)
      expect(update.note?).to be true
    end

    it 'creates milestone update' do
      update = create(:goal_update, :milestone)
      expect(update.milestone?).to be true
    end

    it 'creates status_change update' do
      update = create(:goal_update, :status_change)
      expect(update.status_change?).to be true
    end
  end
end
