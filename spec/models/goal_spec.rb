require 'rails_helper'

RSpec.describe Goal, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:goal_updates).dependent(:destroy) }
    it { should have_many(:goal_steps).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_least(3).is_at_most(200) }
    it { should validate_length_of(:description).is_at_most(2000) }
    it { should validate_presence_of(:goal_type) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:progress_type) }
    it { should validate_numericality_of(:current_value).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:target_value).is_greater_than(0).allow_nil }
    it { should validate_presence_of(:visibility) }

    context 'deadline validation' do
      it 'does not allow past deadline on create' do
        goal = build(:goal, deadline: 1.week.ago)
        expect(goal).not_to be_valid
        expect(goal.errors[:deadline]).to include('must be in the future')
      end

      it 'allows future deadline' do
        goal = build(:goal, deadline: 1.week.from_now)
        expect(goal).to be_valid
      end

      it 'allows nil deadline' do
        goal = build(:goal, deadline: nil)
        expect(goal).to be_valid
      end
    end

    context 'current_value validation' do
      it 'does not allow current_value to exceed target_value' do
        goal = build(:goal, current_value: 150, target_value: 100)
        expect(goal).not_to be_valid
        expect(goal.errors[:current_value]).to include('cannot exceed target value')
      end

      it 'allows current_value equal to target_value' do
        goal = build(:goal, current_value: 100, target_value: 100)
        expect(goal).to be_valid
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:goal_type).with_values(growth: 0, content: 1, skill: 2, business: 3, community: 4, personal: 5) }
    it { should define_enum_for(:status).with_values(draft: 0, active: 1, paused: 2, completed: 3, abandoned: 4, failed: 5) }
    it { should define_enum_for(:progress_type).with_values(percentage: 0, steps: 1, metric: 2, time_based: 3) }
    it { should define_enum_for(:visibility).with_values(private_goal: 0, public_goal: 1) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:active_goal) { create(:goal, :active, user: user) }
    let!(:completed_goal) { create(:goal, :completed, user: user) }
    let!(:draft_goal) { create(:goal, :draft, user: user) }
    let!(:paused_goal) { create(:goal, :paused, user: user) }
    let!(:overdue_goal) { create(:goal, :overdue, user: user) }
    let!(:public_goal) { create(:goal, :public_goal, user: user) }

    it 'returns active goals' do
      expect(Goal.active).to include(active_goal)
      expect(Goal.active).not_to include(completed_goal, draft_goal, paused_goal)
    end

    it 'returns completed goals' do
      expect(Goal.completed).to include(completed_goal)
      expect(Goal.completed).not_to include(active_goal, draft_goal)
    end

    it 'returns draft goals' do
      expect(Goal.draft).to include(draft_goal)
      expect(Goal.draft).not_to include(active_goal, completed_goal)
    end

    it 'returns paused goals' do
      expect(Goal.paused).to include(paused_goal)
      expect(Goal.paused).not_to include(active_goal, completed_goal)
    end

    it 'returns public goals' do
      expect(Goal.public_goals).to include(public_goal)
    end

    it 'returns overdue goals' do
      expect(Goal.overdue).to include(overdue_goal)
      expect(Goal.overdue).not_to include(completed_goal, draft_goal)
    end

    it 'orders by most recent' do
      expect(Goal.recent.first).to eq(public_goal)
    end

    it 'filters by type' do
      growth_goal = create(:goal, :growth, user: user)
      expect(Goal.by_type(:growth)).to include(growth_goal)
    end
  end

  describe 'callbacks' do
    context 'on create' do
      it 'sets started_at for active goals' do
        goal = create(:goal, :active, started_at: nil)
        expect(goal.started_at).not_to be_nil
      end

      it 'does not set started_at for draft goals' do
        goal = create(:goal, :draft, started_at: nil)
        expect(goal.started_at).to be_nil
      end
    end

    context 'on update' do
      it 'sets completed_at when status changes to completed' do
        goal = create(:goal, :active)
        goal.update(status: :completed)
        expect(goal.completed_at).not_to be_nil
      end
    end
  end

  describe '#progress_percentage' do
    it 'returns 0 when target_value is nil' do
      goal = create(:goal, target_value: nil)
      expect(goal.progress_percentage).to eq(0)
    end

    it 'returns 0 when target_value is zero' do
      goal = create(:goal, target_value: 0)
      expect(goal.progress_percentage).to eq(0)
    end

    it 'calculates correct percentage' do
      goal = create(:goal, current_value: 50, target_value: 100)
      expect(goal.progress_percentage).to eq(50.0)
    end

    it 'rounds to 2 decimal places' do
      goal = create(:goal, current_value: 33.333, target_value: 100)
      expect(goal.progress_percentage).to eq(33.33)
    end
  end

  describe '#days_until_deadline' do
    it 'returns nil when no deadline' do
      goal = create(:goal, deadline: nil)
      expect(goal.days_until_deadline).to be_nil
    end

    it 'returns positive days for future deadline' do
      goal = create(:goal, deadline: 7.days.from_now)
      expect(goal.days_until_deadline).to eq(7)
    end

    it 'returns negative days for past deadline' do
      goal = create(:goal, deadline: 7.days.ago)
      expect(goal.days_until_deadline).to eq(-7)
    end
  end

  describe '#days_active' do
    it 'calculates days since started_at' do
      goal = create(:goal, started_at: 10.days.ago)
      expect(goal.days_active).to eq(10)
    end

    it 'uses created_at when started_at is nil' do
      goal = create(:goal, :draft)
      goal.update_column(:created_at, 5.days.ago)
      expect(goal.days_active).to eq(5)
    end
  end

  describe '#overdue?' do
    it 'returns false when no deadline' do
      goal = create(:goal, deadline: nil)
      expect(goal.overdue?).to be false
    end

    it 'returns true for past deadline and active status' do
      goal = create(:goal, :overdue)
      expect(goal.overdue?).to be true
    end

    it 'returns false for future deadline' do
      goal = create(:goal, deadline: 1.week.from_now)
      expect(goal.overdue?).to be false
    end

    it 'returns false for completed goals even if past deadline' do
      goal = create(:goal, :completed, deadline: 1.week.ago)
      expect(goal.overdue?).to be false
    end
  end

  describe '#on_track?' do
    it 'returns nil when no deadline' do
      goal = create(:goal, deadline: nil)
      expect(goal.on_track?).to be_nil
    end

    it 'returns true when progress meets or exceeds expected' do
      goal = create(:goal, :on_track)
      expect(goal.on_track?).to be true
    end

    it 'returns false when progress is behind' do
      goal = create(:goal, started_at: 2.months.ago, deadline: 1.month.from_now, current_value: 20)
      expect(goal.on_track?).to be false
    end
  end

  describe '#mark_completed!' do
    it 'updates status to completed' do
      goal = create(:goal, :active)
      goal.mark_completed!
      expect(goal.status).to eq('completed')
    end

    it 'sets completed_at' do
      goal = create(:goal, :active)
      goal.mark_completed!
      expect(goal.completed_at).not_to be_nil
    end

    it 'sets current_value to target_value' do
      goal = create(:goal, current_value: 50, target_value: 100)
      goal.mark_completed!
      expect(goal.current_value).to eq(goal.target_value)
    end
  end

  describe '#pause!' do
    it 'updates status to paused' do
      goal = create(:goal, :active)
      goal.pause!
      expect(goal.status).to eq('paused')
    end
  end

  describe '#resume!' do
    it 'updates status to active' do
      goal = create(:goal, :paused)
      goal.resume!
      expect(goal.status).to eq('active')
    end
  end

  describe '#abandon!' do
    it 'updates status to abandoned' do
      goal = create(:goal, :active)
      goal.abandon!
      expect(goal.status).to eq('abandoned')
    end
  end

  describe '#mark_failed!' do
    it 'updates status to failed' do
      goal = create(:goal, :active)
      goal.mark_failed!
      expect(goal.status).to eq('failed')
    end
  end

  describe '#update_progress!' do
    let(:goal) { create(:goal, current_value: 25) }

    it 'updates the current_value' do
      goal.update_progress!(50)
      expect(goal.current_value).to eq(50)
    end

    it 'creates a goal_update record' do
      expect {
        goal.update_progress!(50, note: "Great progress!")
      }.to change { goal.goal_updates.count }.by(1)
    end

    it 'includes the note in goal_update' do
      goal.update_progress!(50, note: "Great progress!")
      expect(goal.goal_updates.last.note).to eq("Great progress!")
    end

    it 'marks goal as completed when reaching target' do
      goal.update(target_value: 100, current_value: 90)
      goal.update_progress!(100)
      expect(goal.status).to eq('completed')
    end

    it 'marks goal as completed when exceeding target' do
      goal.update(target_value: 100, current_value: 90)
      goal.update_progress!(105)
      expect(goal.status).to eq('completed')
    end
  end

  describe '#add_step!' do
    let(:goal) { create(:goal) }

    it 'creates a new goal step' do
      expect {
        goal.add_step!("Complete this task")
      }.to change { goal.goal_steps.count }.by(1)
    end

    it 'auto-assigns position' do
      goal.add_step!("First step")
      goal.add_step!("Second step")
      expect(goal.goal_steps.last.position).to eq(2)
    end

    it 'allows custom position' do
      step = goal.add_step!("Custom step", position: 5)
      expect(step.position).to eq(5)
    end
  end

  describe '#steps_progress' do
    let(:goal) { create(:goal, :with_steps) }

    it 'returns correct structure' do
      progress = goal.steps_progress
      expect(progress).to have_key(:completed)
      expect(progress).to have_key(:total)
      expect(progress).to have_key(:percentage)
    end

    it 'calculates correct totals' do
      progress = goal.steps_progress
      expect(progress[:total]).to eq(3)
    end

    it 'calculates completed steps' do
      goal.goal_steps.first.update(completed: true)
      progress = goal.steps_progress
      expect(progress[:completed]).to eq(1)
    end

    it 'calculates percentage' do
      goal.goal_steps.first.update(completed: true)
      progress = goal.steps_progress
      expect(progress[:percentage]).to eq(33.33)
    end

    it 'returns zeros for goal with no steps' do
      goal = create(:goal)
      progress = goal.steps_progress
      expect(progress[:completed]).to eq(0)
      expect(progress[:total]).to eq(0)
      expect(progress[:percentage]).to eq(0)
    end
  end

  describe '#emoji_for_type' do
    it 'returns correct emoji for growth' do
      goal = create(:goal, :growth)
      expect(goal.emoji_for_type).to eq('📈')
    end

    it 'returns correct emoji for content' do
      goal = create(:goal, :content)
      expect(goal.emoji_for_type).to eq('🎬')
    end

    it 'returns correct emoji for all types' do
      expect(create(:goal, :skill).emoji_for_type).to eq('🎮')
      expect(create(:goal, :business).emoji_for_type).to eq('💼')
      expect(create(:goal, :community).emoji_for_type).to eq('🌟')
      expect(create(:goal, :personal).emoji_for_type).to eq('💚')
    end
  end

  describe '#emoji_for_status' do
    it 'returns correct emoji for active' do
      goal = create(:goal, :active)
      expect(goal.emoji_for_status).to eq('🔄')
    end

    it 'returns correct emoji for completed' do
      goal = create(:goal, :completed)
      expect(goal.emoji_for_status).to eq('✅')
    end

    it 'returns correct emoji for all statuses' do
      expect(create(:goal, :draft).emoji_for_status).to eq('📝')
      expect(create(:goal, :paused).emoji_for_status).to eq('⏸️')
      expect(create(:goal, :abandoned).emoji_for_status).to eq('🗑️')
      expect(create(:goal, :failed).emoji_for_status).to eq('❌')
    end
  end
end
