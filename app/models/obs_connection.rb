# app/models/obs_connection.rb
# OBS WebSocket connection (not OAuth-based)
class ObsConnection < ApplicationRecord
  belongs_to :user

  validates :access_token, presence: true
  validates :user_id, uniqueness: true

  before_create :generate_access_token

  def self.privacy_settings_schema
    {
      obs: [
        { key: 'show_obs_status', label: 'Show OBS connection status', default: true },
        { key: 'show_stream_stats', label: 'Show stream stats (bitrate, FPS)', default: true }
      ]
    }
  end

  private

  def generate_access_token
    self.access_token ||= SecureRandom.hex(32)
  end
end
