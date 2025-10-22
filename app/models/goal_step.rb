class GoalStep < ApplicationRecord
  belongs_to :goal

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 200 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: :goal_id }

  # Scopes
  scope :ordered, -> { order(position: :asc) }
  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }

  # Instance methods
  def complete!
    update!(completed: true)
  end

  def uncomplete!
    update!(completed: false)
  end

  def toggle_completion!
    update!(completed: !completed)
  end
end
