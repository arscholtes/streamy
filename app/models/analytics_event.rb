class AnalyticsEvent < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :stream, optional: true

  # Validations
  validates :event_type, presence: true
  validates :occurred_at, presence: true
  validates :event_data, presence: true

  # Event types
  EVENT_TYPES = %w[
    stream_start
    stream_end
    viewer_join
    viewer_leave
    chat_message
    follower_gained
    achievement_unlocked
    game_changed
    subscription_started
    subscription_ended
    donation_received
    raid_received
    raid_sent
    host_received
    milestone_reached
  ].freeze

  validates :event_type, inclusion: { in: EVENT_TYPES }

  # Scopes
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_stream, ->(stream_id) { where(stream_id: stream_id) }
  scope :by_type, ->(event_type) { where(event_type: event_type) }
  scope :since, ->(time) { where('occurred_at >= ?', time) }
  scope :until, ->(time) { where('occurred_at <= ?', time) }
  scope :recent, ->(limit = 100) { order(occurred_at: :desc).limit(limit) }
  scope :chronological, -> { order(occurred_at: :asc) }

  # Instance methods
  def stream_event?
    %w[stream_start stream_end].include?(event_type)
  end

  def viewer_event?
    %w[viewer_join viewer_leave].include?(event_type)
  end

  def engagement_event?
    %w[chat_message follower_gained subscription_started donation_received].include?(event_type)
  end

  def milestone_event?
    %w[achievement_unlocked milestone_reached].include?(event_type)
  end
end
