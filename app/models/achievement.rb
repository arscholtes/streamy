class Achievement < ApplicationRecord
  has_many :user_achievements, dependent: :destroy
  has_many :users, through: :user_achievements

  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :category, presence: true
  validates :points_reward, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :requirement_type, presence: true
  validates :requirement_value, presence: true, numericality: { greater_than: 0 }

  CATEGORIES = %w[
    streaming
    social
    gaming
    community
    milestones
    special
  ].freeze

  REQUIREMENT_TYPES = %w[
    total_stream_hours
    total_viewers
    follower_count
    subscriber_count
    points_earned
    games_played
    custom
  ].freeze

  validates :category, inclusion: { in: CATEGORIES }
  validates :requirement_type, inclusion: { in: REQUIREMENT_TYPES }

  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(:category, :points_reward) }

  def award_to(user)
    return false if user.achievements.include?(self)

    ActiveRecord::Base.transaction do
      user_achievement = user.user_achievements.create!(
        achievement: self,
        earned_at: Time.current,
        progress: requirement_value
      )

      # Award points
      loyalty_points = user.loyalty_point || user.create_loyalty_point!
      loyalty_points.add_points(
        points_reward,
        description: "Achievement unlocked: #{name}",
        transaction_type: 'earned_achievement',
        metadata: { achievement_id: id }
      )

      user_achievement
    end
  end
end
