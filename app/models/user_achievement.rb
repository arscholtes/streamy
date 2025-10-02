class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement

  validates :user_id, uniqueness: { scope: :achievement_id }
  validates :progress, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :earned, -> { where.not(earned_at: nil) }
  scope :in_progress, -> { where(earned_at: nil) }
  scope :recent, ->(limit = 10) { earned.order(earned_at: :desc).limit(limit) }

  def earned?
    earned_at.present?
  end

  def progress_percentage
    return 100 if earned?
    return 0 if achievement.requirement_value.zero?

    ((progress.to_f / achievement.requirement_value) * 100).round(2)
  end

  def update_progress(new_progress)
    return if earned?

    update!(progress: new_progress)

    if progress >= achievement.requirement_value
      complete!
    end
  end

  private

  def complete!
    update!(earned_at: Time.current)
    achievement.award_to(user)
  end
end
