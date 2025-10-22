class Goal < ApplicationRecord
  belongs_to :user
  has_many :goal_updates, dependent: :destroy
  has_many :goal_steps, dependent: :destroy

  # Serialization (Rails 8 syntax)
  serialize :metadata, coder: JSON

  # Enums
  enum :goal_type, {
    growth: 0,
    content: 1,
    skill: 2,
    business: 3,
    community: 4,
    personal: 5
  }, validate: true

  enum :status, {
    draft: 0,
    active: 1,
    paused: 2,
    completed: 3,
    abandoned: 4,
    failed: 5
  }, validate: true

  enum :progress_type, {
    percentage: 0,
    steps: 1,
    metric: 2,
    time_based: 3
  }, validate: true

  enum :visibility, {
    private_goal: 0,
    public_goal: 1
  }, validate: true

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :current_value, numericality: { greater_than_or_equal_to: 0 }
  validates :target_value, numericality: { greater_than: 0 }, allow_nil: true

  validate :deadline_must_be_future, on: :create
  validate :current_value_cannot_exceed_target

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :completed, -> { where(status: :completed) }
  scope :draft, -> { where(status: :draft) }
  scope :paused, -> { where(status: :paused) }
  scope :by_type, ->(type) { where(goal_type: type) }
  scope :public_goals, -> { where(visibility: :public_goal) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_deadline, -> { order(deadline: :asc) }
  scope :overdue, -> { where('deadline < ? AND status IN (?)', Time.current, [statuses[:active], statuses[:paused]]) }

  # Callbacks
  before_create :set_started_at, if: -> { active? }
  after_update :set_completed_at, if: -> { saved_change_to_status? && completed? }

  # Instance methods
  def progress_percentage
    return 0 if target_value.nil? || target_value.zero?
    ((current_value / target_value) * 100).round(2)
  end

  def days_until_deadline
    return nil if deadline.nil?
    (deadline.to_date - Date.current).to_i
  end

  def days_active
    start_date = started_at || created_at
    (Date.current - start_date.to_date).to_i
  end

  def overdue?
    deadline.present? && deadline < Time.current && (active? || paused?)
  end

  def on_track?
    return nil if deadline.nil? || target_value.nil? || target_value.zero?

    days_total = (deadline.to_date - (started_at || created_at).to_date).to_i
    days_passed = days_active

    return true if days_total.zero?

    expected_progress = (days_passed.to_f / days_total * 100)
    actual_progress = progress_percentage

    actual_progress >= expected_progress
  end

  def mark_completed!
    update!(
      status: :completed,
      completed_at: Time.current,
      current_value: target_value
    )
  end

  def pause!
    update!(status: :paused)
  end

  def resume!
    update!(status: :active)
  end

  def abandon!
    update!(status: :abandoned)
  end

  def mark_failed!
    update!(status: :failed)
  end

  def update_progress!(new_value, note: nil)
    self.current_value = new_value

    # Create goal update record
    goal_updates.create!(
      value_before: current_value_was,
      value_after: new_value,
      note: note,
      update_type: 'progress'
    )

    # Check if goal is completed
    if target_value.present? && new_value >= target_value
      mark_completed!
    else
      save!
    end

    self
  end

  def add_step!(title, position: nil)
    position ||= goal_steps.maximum(:position).to_i + 1
    goal_steps.create!(
      title: title,
      position: position,
      completed: false
    )
  end

  def steps_progress
    return { completed: 0, total: 0, percentage: 0 } if goal_steps.empty?

    total = goal_steps.count
    completed = goal_steps.where(completed: true).count
    percentage = (completed.to_f / total * 100).round(2)

    { completed: completed, total: total, percentage: percentage }
  end

  def emoji_for_type
    {
      growth: '📈',
      content: '🎬',
      skill: '🎮',
      business: '💼',
      community: '🌟',
      personal: '💚'
    }[goal_type.to_sym]
  end

  def emoji_for_status
    {
      draft: '📝',
      active: '🔄',
      paused: '⏸️',
      completed: '✅',
      abandoned: '🗑️',
      failed: '❌'
    }[status.to_sym]
  end

  private

  def deadline_must_be_future
    if deadline.present? && deadline < Time.current
      errors.add(:deadline, 'must be in the future')
    end
  end

  def current_value_cannot_exceed_target
    if target_value.present? && current_value.present? && current_value > target_value
      errors.add(:current_value, 'cannot exceed target value')
    end
  end

  def set_started_at
    self.started_at ||= Time.current
  end

  def set_completed_at
    self.completed_at = Time.current if completed?
  end
end
