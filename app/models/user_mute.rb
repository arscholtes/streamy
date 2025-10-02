class UserMute < ApplicationRecord
  belongs_to :user, optional: true

  # Validations
  validates :discord_id, presence: true
  validates :moderator_discord_id, presence: true
  validates :guild_id, presence: true
  validates :muted_at, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :for_guild, ->(guild_id) { where(guild_id: guild_id) }
  scope :for_user, ->(discord_id) { where(discord_id: discord_id) }
  scope :active_mutes, -> { where(active: true) }
  scope :expired, -> {
    active_mutes.where(
      "datetime(muted_at, '+' || duration_minutes || ' minutes') < ?",
      Time.current
    )
  }
  scope :recent, -> { order(muted_at: :desc) }

  # Instance methods
  def ends_at
    muted_at + duration_minutes.minutes
  end

  def expired?
    Time.current >= ends_at
  end

  def time_remaining
    return 0 if expired?
    ((ends_at - Time.current) / 60).to_i # in minutes
  end

  def unmute!
    update!(active: false, unmuted_at: Time.current)
  end

  # Class methods
  def self.active_for_user(discord_id, guild_id)
    for_user(discord_id).for_guild(guild_id).active_mutes.where(
      "datetime(muted_at, '+' || duration_minutes || ' minutes') > ?",
      Time.current
    ).first
  end

  def self.check_and_expire_mutes
    expired.find_each(&:unmute!)
  end
end
