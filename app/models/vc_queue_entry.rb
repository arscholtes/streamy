class VcQueueEntry < ApplicationRecord
  belongs_to :user

  validates :discord_user_id, presence: true
  validates :priority, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :joined_at, presence: true

  STATUSES = %w[waiting active completed cancelled].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :waiting, -> { where(status: 'waiting') }
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_priority, -> { order(priority: :desc, joined_at: :asc) }

  def wait_time
    return nil unless joined_at

    if left_at
      left_at - joined_at
    else
      Time.current - joined_at
    end
  end

  def waiting?
    status == 'waiting'
  end

  def active?
    status == 'active'
  end

  def mark_active!
    update!(status: 'active')
  end

  def mark_completed!
    update!(status: 'completed', left_at: Time.current)
  end

  def mark_cancelled!
    update!(status: 'cancelled', left_at: Time.current)
  end

  # Calculate priority based on various factors
  def self.calculate_priority(user, loyalty_level: nil)
    base_priority = 0

    # Subscriber tier bonus
    case user.subscription_tier
    when 'enterprise'
      base_priority += 50
    when 'pro'
      base_priority += 25
    end

    # Loyalty level bonus
    if loyalty_level
      base_priority += loyalty_level
    elsif user.loyalty_point
      base_priority += user.loyalty_point.level
    end

    base_priority
  end
end
