class ChatBan < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :user
  belongs_to :stream
  belongs_to :banned_by, class_name: 'User', foreign_key: 'banned_by_id'

  # VALIDATIONS
  validates :banned_at, presence: true
  validates :permanent, inclusion: { in: [true, false] }
  validate :expires_at_required_for_temporary_bans
  validate :user_not_stream_owner

  # CALLBACKS
  before_validation :set_banned_at, on: :create
  before_validation :set_permanent_flag

  # SCOPES
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :permanent, -> { where(permanent: true) }
  scope :temporary, -> { where(permanent: false) }
  scope :expired, -> { temporary.where('expires_at <= ?', Time.current) }
  scope :not_expired, -> { where('permanent = ? OR expires_at > ?', true, Time.current) }
  scope :for_stream, ->(stream_id) { where(stream_id: stream_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(banned_at: :desc) }

  # DELEGATIONS
  delegate :username, to: :user, prefix: true, allow_nil: true
  delegate :username, to: :banned_by, prefix: true, allow_nil: true

  # CLASS METHODS

  # Find active ban for a user in a stream
  def self.active_ban_for(user_id, stream_id)
    active
      .for_user(user_id)
      .for_stream(stream_id)
      .not_expired
      .order(banned_at: :desc)
      .first
  end

  # Check if user is banned from stream
  def self.user_banned?(user_id, stream_id)
    active_ban_for(user_id, stream_id).present?
  end

  # Expire all expired temporary bans
  def self.expire_temporary_bans
    expired.active.update_all(active: false)
  end

  # INSTANCE METHODS

  # Check if this ban is still valid
  def valid_ban?
    return false unless active?
    return true if permanent?
    expires_at.present? && expires_at > Time.current
  end

  # Check if ban has expired
  def expired?
    return false if permanent?
    expires_at.present? && expires_at <= Time.current
  end

  # Lift the ban
  def lift!
    update!(active: false)
  end

  # Time remaining on ban (nil for permanent bans)
  def time_remaining
    return nil if permanent?
    return 0 if expired?
    (expires_at - Time.current).to_i
  end

  # Human-readable time remaining
  def time_remaining_in_words
    return "Permanent" if permanent?
    return "Expired" if expired?

    seconds = time_remaining
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 24
      days = hours / 24
      "#{days} day#{'s' if days != 1}"
    elsif hours > 0
      "#{hours} hour#{'s' if hours != 1}"
    else
      "#{minutes} minute#{'s' if minutes != 1}"
    end
  end

  private

  def set_banned_at
    self.banned_at ||= Time.current
  end

  def set_permanent_flag
    self.permanent = expires_at.nil? if permanent.nil?
  end

  def expires_at_required_for_temporary_bans
    if !permanent && expires_at.blank?
      errors.add(:expires_at, "must be set for temporary bans")
    end
  end

  def user_not_stream_owner
    if user_id == stream&.user_id
      errors.add(:user, "cannot ban the stream owner")
    end
  end
end
