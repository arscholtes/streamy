require 'rails_helper'

RSpec.describe LoyaltyPoint, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:loyalty_point) }

    it { should validate_presence_of(:points) }
    it { should validate_numericality_of(:points).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:level) }
    it { should validate_numericality_of(:level).is_greater_than_or_equal_to(1) }
    it { should validate_presence_of(:total_earned) }
    it { should validate_numericality_of(:total_earned).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:total_spent) }
    it { should validate_numericality_of(:total_spent).is_greater_than_or_equal_to(0) }
    it { should validate_uniqueness_of(:user_id) }
  end

  describe 'constants' do
    it 'has POINTS_PER_LEVEL_BASE' do
      expect(LoyaltyPoint::POINTS_PER_LEVEL_BASE).to eq(100)
    end

    it 'has LEVEL_MULTIPLIER' do
      expect(LoyaltyPoint::LEVEL_MULTIPLIER).to eq(1.5)
    end
  end

  describe '#add_points' do
    let(:user) { create(:user) }
    let(:loyalty_point) { create(:loyalty_point, user: user, points: 50, total_earned: 50, level: 1) }

    context 'with valid amount' do
      it 'adds points to current balance' do
        expect {
          loyalty_point.add_points(100)
        }.to change { loyalty_point.reload.points }.by(100)
      end

      it 'updates total_earned' do
        expect {
          loyalty_point.add_points(100)
        }.to change { loyalty_point.reload.total_earned }.by(100)
      end

      it 'creates a loyalty transaction' do
        expect {
          loyalty_point.add_points(100, description: 'Test reward')
        }.to change { user.loyalty_transactions.count }.by(1)
      end

      it 'returns true' do
        expect(loyalty_point.add_points(100)).to be true
      end

      it 'levels up when reaching threshold' do
        loyalty_point.update(total_earned: 0, points: 0, level: 1)
        expect {
          loyalty_point.add_points(150)
        }.to change { loyalty_point.reload.level }.from(1).to(2)
      end
    end

    context 'with invalid amount' do
      it 'returns false for zero or negative amount' do
        expect(loyalty_point.add_points(0)).to be false
        expect(loyalty_point.add_points(-10)).to be false
      end

      it 'does not change points' do
        expect {
          loyalty_point.add_points(-10)
        }.not_to change { loyalty_point.reload.points }
      end
    end
  end

  describe '#spend_points' do
    let(:user) { create(:user) }
    let(:loyalty_point) { create(:loyalty_point, user: user, points: 100, total_spent: 0, level: 1) }

    context 'with valid amount' do
      it 'deducts points from current balance' do
        expect {
          loyalty_point.spend_points(50)
        }.to change { loyalty_point.reload.points }.by(-50)
      end

      it 'updates total_spent' do
        expect {
          loyalty_point.spend_points(50)
        }.to change { loyalty_point.reload.total_spent }.by(50)
      end

      it 'creates a loyalty transaction with negative amount' do
        loyalty_point.spend_points(50, description: 'Test purchase')
        transaction = user.loyalty_transactions.last
        expect(transaction.amount).to eq(-50)
      end

      it 'returns true' do
        expect(loyalty_point.spend_points(50)).to be true
      end
    end

    context 'with invalid amount' do
      it 'returns false when insufficient points' do
        expect(loyalty_point.spend_points(200)).to be false
      end

      it 'returns false for zero or negative amount' do
        expect(loyalty_point.spend_points(0)).to be false
        expect(loyalty_point.spend_points(-10)).to be false
      end

      it 'does not change points when invalid' do
        expect {
          loyalty_point.spend_points(200)
        }.not_to change { loyalty_point.reload.points }
      end
    end
  end

  describe '#points_to_next_level' do
    it 'calculates points needed to reach next level' do
      loyalty_point = create(:loyalty_point, points: 50, level: 1, total_earned: 50)
      expect(loyalty_point.points_to_next_level).to eq(50) # 100 required for level 2
    end

    it 'returns correct value for higher levels' do
      loyalty_point = create(:loyalty_point, points: 0, level: 2, total_earned: 100)
      # Level 2 -> 3 requires 100 + 150 = 250 total
      expect(loyalty_point.points_to_next_level).to eq(150)
    end
  end

  describe '#points_required_for_level' do
    it 'returns 0 for level 1' do
      loyalty_point = build(:loyalty_point)
      expect(loyalty_point.points_required_for_level(1)).to eq(0)
    end

    it 'calculates correctly for level 2' do
      loyalty_point = build(:loyalty_point)
      expect(loyalty_point.points_required_for_level(2)).to eq(100)
    end

    it 'calculates correctly for level 3' do
      loyalty_point = build(:loyalty_point)
      # Level 3 = 100 + 150 = 250
      expect(loyalty_point.points_required_for_level(3)).to eq(250)
    end
  end
end
