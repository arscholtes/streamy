class LoyaltyPoint < ApplicationRecord
  belongs_to :user

  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :level, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :total_earned, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_spent, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: true

  # Points per level calculation (exponential growth)
  POINTS_PER_LEVEL_BASE = 100
  LEVEL_MULTIPLIER = 1.5

  def add_points(amount, description: nil, transaction_type: 'earned_custom', metadata: {})
    return false if amount <= 0

    ActiveRecord::Base.transaction do
      update!(
        points: points + amount,
        total_earned: total_earned + amount
      )

      # Record transaction
      user.loyalty_transactions.create!(
        transaction_type: transaction_type,
        amount: amount,
        description: description,
        metadata: metadata
      )

      # Check for level up
      check_and_level_up!
    end

    true
  end

  def spend_points(amount, description: nil, transaction_type: 'spent_custom', metadata: {})
    return false if amount <= 0 || points < amount

    ActiveRecord::Base.transaction do
      update!(
        points: points - amount,
        total_spent: total_spent + amount
      )

      # Record transaction
      user.loyalty_transactions.create!(
        transaction_type: transaction_type,
        amount: -amount,
        description: description,
        metadata: metadata
      )
    end

    true
  end

  def points_to_next_level
    points_required_for_level(level + 1) - points
  end

  def points_required_for_level(target_level)
    return 0 if target_level <= 1

    total = 0
    (1...target_level).each do |lvl|
      total += (POINTS_PER_LEVEL_BASE * (LEVEL_MULTIPLIER ** (lvl - 1))).to_i
    end
    total
  end

  private

  def check_and_level_up!
    next_level_points = points_required_for_level(level + 1)

    while total_earned >= next_level_points
      update!(level: level + 1)
      next_level_points = points_required_for_level(level + 1)
    end
  end
end
