class ModeratorRole < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :stream
  has_many :stream_moderators, dependent: :destroy
  has_many :moderators, through: :stream_moderators, source: :user

  # VALIDATIONS
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :name, uniqueness: { scope: :stream_id, message: "already exists for this stream" }

  # SCOPES
  scope :for_stream, ->(stream_id) { where(stream_id: stream_id) }
  scope :with_permission, ->(permission) { where(permission => true) }

  # PERMISSION CONSTANTS
  PERMISSIONS = %i[
    can_timeout_users
    can_ban_users
    can_delete_messages
    can_manage_slow_mode
    can_manage_emote_only
    can_manage_moderators
  ].freeze

  # CLASS METHODS

  # Create default moderator roles for a stream
  def self.create_defaults_for_stream(stream)
    [
      {
        name: "Full Moderator",
        description: "Full moderation permissions including managing other moderators",
        can_timeout_users: true,
        can_ban_users: true,
        can_delete_messages: true,
        can_manage_slow_mode: true,
        can_manage_emote_only: true,
        can_manage_moderators: true
      },
      {
        name: "Chat Moderator",
        description: "Can moderate chat but cannot manage other moderators",
        can_timeout_users: true,
        can_ban_users: false,
        can_delete_messages: true,
        can_manage_slow_mode: true,
        can_manage_emote_only: true,
        can_manage_moderators: false
      },
      {
        name: "Junior Moderator",
        description: "Limited moderation - can timeout and delete messages only",
        can_timeout_users: true,
        can_ban_users: false,
        can_delete_messages: true,
        can_manage_slow_mode: false,
        can_manage_emote_only: false,
        can_manage_moderators: false
      }
    ].map { |attrs| stream.moderator_roles.create!(attrs) }
  end

  # INSTANCE METHODS

  # Check if this role has a specific permission
  def has_permission?(permission)
    return false unless PERMISSIONS.include?(permission.to_sym)
    public_send(permission)
  end

  # Get all enabled permissions for this role
  def enabled_permissions
    PERMISSIONS.select { |permission| public_send(permission) }
  end

  # Get human-readable permission names
  def permission_names
    enabled_permissions.map { |p| p.to_s.humanize }
  end

  # Check if this is a full moderator role (all permissions enabled)
  def full_moderator?
    PERMISSIONS.all? { |permission| public_send(permission) }
  end

  # Count how many permissions are enabled
  def permission_count
    enabled_permissions.count
  end

  # Duplicate this role with a new name
  def duplicate(new_name)
    dup.tap do |new_role|
      new_role.name = new_name
      new_role.description = "Copy of #{name}"
    end
  end
end
