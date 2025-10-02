class ModerationAction < ApplicationRecord
  belongs_to :user

  # Action types supported
  ACTION_TYPES = %w[
    warn
    mute
    unmute
    kick
    ban
    unban
    purge
    slowmode
    lockdown
    unlock
  ].freeze

  # Validations
  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :moderator_discord_id, presence: true
  validates :target_discord_id, presence: true
  validates :guild_id, presence: true
  validates :performed_at, presence: true

  # Scopes
  scope :for_guild, ->(guild_id) { where(guild_id: guild_id) }
  scope :for_target, ->(discord_id) { where(target_discord_id: discord_id) }
  scope :by_type, ->(action_type) { where(action_type: action_type) }
  scope :recent, -> { order(performed_at: :desc) }

  # Class methods
  def self.log_action(action_type:, moderator_discord_id:, target_discord_id:, guild_id:, user: nil, reason: nil, metadata: {})
    create!(
      action_type: action_type,
      moderator_discord_id: moderator_discord_id,
      target_discord_id: target_discord_id,
      guild_id: guild_id,
      user: user,
      reason: reason,
      metadata: metadata,
      performed_at: Time.current
    )
  end
end
