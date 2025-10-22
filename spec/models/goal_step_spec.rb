require 'rails_helper'

RSpec.describe GoalStep, type: :model do
  describe 'associations' do
    it { should belong_to(:goal) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_least(3).is_at_most(200) }
    it { should validate_presence_of(:position) }
    it { should validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

    it 'validates uniqueness of position scoped to goal' do
      goal = create(:goal)
      create(:goal_step, goal: goal, position: 1)
      duplicate = build(:goal_step, goal: goal, position: 1)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:position]).to include('has already been taken')
    end

    it 'allows same position for different goals' do
      goal1 = create(:goal)
      goal2 = create(:goal)
      create(:goal_step, goal: goal1, position: 1)
      step2 = build(:goal_step, goal: goal2, position: 1)

      expect(step2).to be_valid
    end
  end

  describe 'scopes' do
    let(:goal) { create(:goal) }
    let!(:step1) { create(:goal_step, goal: goal, position: 0) }
    let!(:step3) { create(:goal_step, goal: goal, position: 2) }
    let!(:step2) { create(:goal_step, goal: goal, position: 1) }
    let!(:completed_step) { create(:goal_step, :completed, goal: goal, position: 3) }
    let!(:pending_step) { create(:goal_step, :pending, goal: goal, position: 4) }

    it 'orders by position' do
      expect(goal.goal_steps.ordered).to eq([step1, step2, step3, completed_step, pending_step])
    end

    it 'returns completed steps' do
      expect(goal.goal_steps.completed).to include(completed_step)
      expect(goal.goal_steps.completed).not_to include(pending_step)
    end

    it 'returns pending steps' do
      expect(goal.goal_steps.pending).to include(step1, step2, step3, pending_step)
      expect(goal.goal_steps.pending).not_to include(completed_step)
    end
  end

  describe '#complete!' do
    it 'marks step as completed' do
      step = create(:goal_step, completed: false)
      step.complete!
      expect(step.completed).to be true
    end
  end

  describe '#uncomplete!' do
    it 'marks step as not completed' do
      step = create(:goal_step, :completed)
      step.uncomplete!
      expect(step.completed).to be false
    end
  end

  describe '#toggle_completion!' do
    it 'toggles from false to true' do
      step = create(:goal_step, completed: false)
      step.toggle_completion!
      expect(step.completed).to be true
    end

    it 'toggles from true to false' do
      step = create(:goal_step, :completed)
      step.toggle_completion!
      expect(step.completed).to be false
    end
  end

  describe 'creation' do
    it 'can be created with factory' do
      step = create(:goal_step)
      expect(step).to be_valid
      expect(step.completed).to be false
    end

    it 'can be created as completed' do
      step = create(:goal_step, :completed)
      expect(step.completed).to be true
    end

    it 'auto-generates position' do
      goal = create(:goal)
      step1 = create(:goal_step, goal: goal)
      step2 = create(:goal_step, goal: goal)
      expect(step2.position).to eq(step1.position + 1)
    end
  end
end
