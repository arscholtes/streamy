class StreamModerator < ApplicationRecord
  include ActionView::Helpers::DateHelper

  # ASSOCIATIONS
  belongs_to :user
  belongs_to :stream
  belongs_to :moderator_role
  belongs_to :appointed_by, class_name: 'User', foreign_key: 'appointed_by_id', optional: true

  # VALIDATIONS
  validates :user_id, uniqueness: { scope: :stream_id, message: "is already a moderator for this stream" }
  validates :appointed_at, presence: true
  validate :cannot_moderate_own_stream
  validate :appointed_by_is_owner_or_mod, on: :create

  # CALLBACKS
  before_validation :set_appointed_at, on: :create

  # SCOPES
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :for_stream, ->(stream_id) { where(stream_id: stream_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :with_role, ->(role_name) {
    joins(:moderator_role).where(moderator_roles: { name: role_name })
  }
  scope :recent, -> { order(appointed_at: :desc) }

  # DELEGATIONS
  delegate :name, to: :moderator_role, prefix: true, allow_nil: true
  delegate :username, to: :user, prefix: true, allow_nil: true
  delegate :username, to: :appointed_by, prefix: true, allow_nil: true

  # Delegate permission checks to the role
  ModeratorRole::PERMISSIONS.each do |permission|
    delegate permission, to: :moderator_role, allow_nil: false
  end

  # INSTANCE METHODS

  # Check if this moderator has a specific permission
  def has_permission?(permission)
    return false unless active?
    moderator_role.has_permission?(permission)
  end

  # Deactivate this moderator
  def deactivate!
    update!(active: false)
  end

  # Reactivate this moderator
  def reactivate!
    update!(active: true)
  end

  # Change the moderator's role
  def change_role!(new_role)
    update!(moderator_role: new_role)
  end

  # Check if this moderator can manage other moderators
  def can_manage_mods?
    active? && moderator_role.can_manage_moderators
  end

  # Get all permissions as a hash
  def permissions_hash
    ModeratorRole::PERMISSIONS.each_with_object({}) do |permission, hash|
      hash[permission] = has_permission?(permission)
    end
  end

  # Duration as a moderator
  def duration
    Time.current - appointed_at
  end

  # Human-readable duration
  def duration_in_words
    distance_of_time_in_words(appointed_at, Time.current)
  end

  private

  def set_appointed_at
    self.appointed_at ||= Time.current
  end

  def cannot_moderate_own_stream
    if user_id == stream&.user_id
      errors.add(:user, "cannot be a moderator of their own stream")
    end
  end

  def appointed_by_is_owner_or_mod
    return if appointed_by_id.blank? # Allow nil for system appointments
    return if appointed_by_id == stream&.user_id # Stream owner can appoint

    # Check if appointer is a moderator with manage_moderators permission
    appointer = StreamModerator.find_by(
      user_id: appointed_by_id,
      stream_id: stream_id,
      active: true
    )

    if appointer && !appointer.can_manage_moderators
      errors.add(:appointed_by, "does not have permission to manage moderators")
    elsif !appointer
      errors.add(:appointed_by, "must be the stream owner or an active moderator")
    end
  end
end
