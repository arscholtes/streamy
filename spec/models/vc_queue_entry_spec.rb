require 'rails_helper'

RSpec.describe VcQueueEntry, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:discord_user_id) }
    it { should validate_presence_of(:priority) }
    it { should validate_numericality_of(:priority).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:position) }
    it { should validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:joined_at) }
    it { should validate_inclusion_of(:status).in_array(VcQueueEntry::STATUSES) }
  end

  describe 'constants' do
    it 'has STATUSES' do
      expect(VcQueueEntry::STATUSES).to match_array(%w[waiting active completed cancelled])
    end
  end

  describe 'scopes' do
    let!(:waiting_entry) { create(:vc_queue_entry, status: 'waiting') }
    let!(:active_entry) { create(:vc_queue_entry, status: 'active') }
    let!(:completed_entry) { create(:vc_queue_entry, status: 'completed') }

    describe '.waiting' do
      it 'returns only waiting entries' do
        expect(VcQueueEntry.waiting).to include(waiting_entry)
        expect(VcQueueEntry.waiting).not_to include(active_entry, completed_entry)
      end
    end

    describe '.active' do
      it 'returns only active entries' do
        expect(VcQueueEntry.active).to include(active_entry)
        expect(VcQueueEntry.active).not_to include(waiting_entry, completed_entry)
      end
    end

    describe '.completed' do
      it 'returns only completed entries' do
        expect(VcQueueEntry.completed).to include(completed_entry)
        expect(VcQueueEntry.completed).not_to include(waiting_entry, active_entry)
      end
    end

    describe '.by_priority' do
      let!(:low_priority) { create(:vc_queue_entry, priority: 10, joined_at: 2.hours.ago) }
      let!(:high_priority) { create(:vc_queue_entry, priority: 100, joined_at: 1.hour.ago) }

      it 'orders by priority descending, then by joined_at ascending' do
        expect(VcQueueEntry.by_priority.first).to eq(high_priority)
      end
    end
  end

  describe '#wait_time' do
    it 'calculates wait time when still waiting' do
      entry = create(:vc_queue_entry, joined_at: 30.minutes.ago, left_at: nil)
      expect(entry.wait_time).to be_within(5).of(30.minutes)
    end

    it 'calculates total wait time when left' do
      entry = create(:vc_queue_entry, joined_at: 1.hour.ago, left_at: 30.minutes.ago)
      expect(entry.wait_time).to be_within(5).of(30.minutes)
    end

    it 'returns nil when joined_at is nil' do
      entry = build(:vc_queue_entry, joined_at: nil)
      expect(entry.wait_time).to be_nil
    end
  end

  describe '#waiting?' do
    it 'returns true when status is waiting' do
      entry = build(:vc_queue_entry, status: 'waiting')
      expect(entry.waiting?).to be true
    end

    it 'returns false when status is not waiting' do
      entry = build(:vc_queue_entry, status: 'active')
      expect(entry.waiting?).to be false
    end
  end

  describe '#active?' do
    it 'returns true when status is active' do
      entry = build(:vc_queue_entry, status: 'active')
      expect(entry.active?).to be true
    end

    it 'returns false when status is not active' do
      entry = build(:vc_queue_entry, status: 'waiting')
      expect(entry.active?).to be false
    end
  end

  describe '#mark_active!' do
    it 'updates status to active' do
      entry = create(:vc_queue_entry, status: 'waiting')
      entry.mark_active!
      expect(entry.reload.status).to eq('active')
    end
  end

  describe '#mark_completed!' do
    it 'updates status to completed' do
      entry = create(:vc_queue_entry, status: 'active')
      entry.mark_completed!
      expect(entry.reload.status).to eq('completed')
    end

    it 'sets left_at timestamp' do
      entry = create(:vc_queue_entry, status: 'active')
      entry.mark_completed!
      expect(entry.reload.left_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '#mark_cancelled!' do
    it 'updates status to cancelled' do
      entry = create(:vc_queue_entry, status: 'waiting')
      entry.mark_cancelled!
      expect(entry.reload.status).to eq('cancelled')
    end

    it 'sets left_at timestamp' do
      entry = create(:vc_queue_entry, status: 'waiting')
      entry.mark_cancelled!
      expect(entry.reload.left_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '.calculate_priority' do
    let(:user) { create(:user) }

    it 'calculates base priority of 0 for free users' do
      user.update(subscription_tier: 'free')
      priority = VcQueueEntry.calculate_priority(user)
      expect(priority).to eq(0)
    end

    it 'adds 25 priority for pro subscribers' do
      user.update(subscription_tier: 'pro')
      priority = VcQueueEntry.calculate_priority(user)
      expect(priority).to eq(25)
    end

    it 'adds 50 priority for enterprise subscribers' do
      user.update(subscription_tier: 'enterprise')
      priority = VcQueueEntry.calculate_priority(user)
      expect(priority).to eq(50)
    end

    it 'adds loyalty level to priority' do
      user.update(subscription_tier: 'free')
      loyalty_point = create(:loyalty_point, user: user, level: 5)
      priority = VcQueueEntry.calculate_priority(user)
      expect(priority).to eq(5)
    end

    it 'combines subscription tier and loyalty level' do
      user.update(subscription_tier: 'pro')
      loyalty_point = create(:loyalty_point, user: user, level: 10)
      priority = VcQueueEntry.calculate_priority(user)
      expect(priority).to eq(35) # 25 + 10
    end
  end
end
