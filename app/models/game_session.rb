class GameSession < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :stream, optional: true

  # Validations
  validates :platform, presence: true, inclusion: { in: %w[steam battlenet riot] }
  validates :game_name, presence: true
  validates :game_id, presence: true
  validates :started_at, presence: true
  validate :ended_at_after_started_at, if: :ended_at?

  # Scopes
  scope :active, -> { where(ended_at: nil) }
  scope :ended, -> { where.not(ended_at: nil) }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :for_game, ->(game_id) { where(game_id: game_id) }
  scope :recent, -> { order(started_at: :desc) }

  # Instance methods
  def active?
    ended_at.nil?
  end

  def ended?
    ended_at.present?
  end

  def duration
    return nil unless ended?
    ended_at - started_at
  end

  def duration_in_minutes
    return nil unless ended?
    (duration / 60).round
  end

  def end_session!
    update!(ended_at: Time.current)
  end

  private

  def ended_at_after_started_at
    if ended_at.present? && ended_at < started_at
      errors.add(:ended_at, "must be after started_at")
    end
  end
end
