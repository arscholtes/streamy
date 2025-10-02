class UserWarning < ApplicationRecord
  belongs_to :user, optional: true

  # Validations
  validates :discord_id, presence: true
  validates :moderator_discord_id, presence: true
  validates :guild_id, presence: true
  validates :warned_at, presence: true

  # Scopes
  scope :for_guild, ->(guild_id) { where(guild_id: guild_id) }
  scope :for_user, ->(discord_id) { where(discord_id: discord_id) }
  scope :recent, -> { order(warned_at: :desc) }
  scope :active, -> { where('warned_at > ?', 30.days.ago) } # Warnings expire after 30 days

  # Class methods
  def self.count_for_user(discord_id, guild_id)
    for_user(discord_id).for_guild(guild_id).active.count
  end

  def self.recent_for_user(discord_id, guild_id, limit = 5)
    for_user(discord_id).for_guild(guild_id).recent.limit(limit)
  end

  def self.clear_for_user(discord_id, guild_id)
    for_user(discord_id).for_guild(guild_id).delete_all
  end
end
