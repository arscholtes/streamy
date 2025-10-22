class GoalUpdate < ApplicationRecord
  belongs_to :goal
  belongs_to :user

  # Enums
  enum :update_type, {
    progress: 0,
    note: 1,
    milestone: 2,
    status_change: 3
  }, validate: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_goal, ->(goal_id) { where(goal_id: goal_id) }

  # Instance methods
  def progress_delta
    return nil if value_before.nil? || value_after.nil?
    value_after - value_before
  end

  def progress_delta_percentage
    return nil if value_before.nil? || value_after.nil? || value_before.zero?
    ((value_after - value_before) / value_before * 100).round(2)
  end
end
