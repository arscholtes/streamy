class ChatTimeout < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :user
  belongs_to :stream
  belongs_to :timed_out_by, class_name: 'User', foreign_key: 'timed_out_by_id'

  # VALIDATIONS
  validates :timed_out_at, presence: true
  validates :expires_at, presence: true
  validates :duration_seconds, presence: true, numericality: { greater_than: 0 }
  validate :user_not_stream_owner

  # CALLBACKS
  before_validation :set_timed_out_at, on: :create
  before_validation :calculate_expires_at

  # SCOPES
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :not_expired, -> { where('expires_at > ?', Time.current) }
  scope :for_stream, ->(stream_id) { where(stream_id: stream_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(timed_out_at: :desc) }

  # DELEGATIONS
  delegate :username, to: :user, prefix: true, allow_nil: true
  delegate :username, to: :timed_out_by, prefix: true, allow_nil: true

  # TIMEOUT DURATIONS (in seconds)
  DURATIONS = {
    '1 minute' => 60,
    '5 minutes' => 300,
    '10 minutes' => 600,
    '30 minutes' => 1800,
    '1 hour' => 3600,
    '6 hours' => 21600,
    '24 hours' => 86400
  }.freeze

  # CLASS METHODS

  # Find active timeout for a user in a stream
  def self.active_timeout_for(user_id, stream_id)
    active
      .for_user(user_id)
      .for_stream(stream_id)
      .not_expired
      .order(timed_out_at: :desc)
      .first
  end

  # Check if user is timed out from stream
  def self.user_timed_out?(user_id, stream_id)
    active_timeout_for(user_id, stream_id).present?
  end

  # Expire all expired timeouts
  def self.expire_timeouts
    expired.active.update_all(active: false)
  end

  # INSTANCE METHODS

  # Check if timeout is still active
  def valid_timeout?
    active? && !expired?
  end

  # Check if timeout has expired
  def expired?
    expires_at <= Time.current
  end

  # End the timeout early
  def end_timeout!
    update!(active: false, expires_at: Time.current)
  end

  # Time remaining in seconds
  def time_remaining
    return 0 if expired?
    (expires_at - Time.current).to_i
  end

  # Time remaining in minutes
  def time_remaining_minutes
    (time_remaining / 60.0).ceil
  end

  # Human-readable time remaining
  def time_remaining_in_words
    return "Expired" if expired?

    seconds = time_remaining
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end

  # Duration in human-readable format
  def duration_in_words
    seconds = duration_seconds
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 0
      "#{hours} hour#{'s' if hours != 1}"
    else
      "#{minutes} minute#{'s' if minutes != 1}"
    end
  end

  private

  def set_timed_out_at
    self.timed_out_at ||= Time.current
  end

  def calculate_expires_at
    if timed_out_at.present? && duration_seconds.present? && expires_at.blank?
      self.expires_at = timed_out_at + duration_seconds.seconds
    end
  end

  def user_not_stream_owner
    if user_id == stream&.user_id
      errors.add(:user, "cannot timeout the stream owner")
    end
  end
end
