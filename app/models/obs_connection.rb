# app/models/obs_connection.rb
# OBS WebSocket connection model
# Stores connection details for Discord bot's OBS remote control feature
class ObsConnection < ApplicationRecord
  belongs_to :user

  # Validations
  validates :user_id, uniqueness: true
  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Optional access token for additional security
  before_create :generate_access_token

  # Scopes
  scope :connected, -> { where(connected: true) }
  scope :disconnected, -> { where(connected: false) }
  scope :recent, -> { order(last_connected_at: :desc) }

  # Privacy settings schema
  def self.privacy_settings_schema
    {
      obs: [
        { key: 'show_obs_status', label: 'Show OBS connection status', default: true },
        { key: 'show_stream_stats', label: 'Show stream stats (bitrate, FPS)', default: true },
        { key: 'allow_remote_control', label: 'Allow remote control via Discord', default: true }
      ]
    }
  end

  # Instance methods

  # Calculate total uptime from connection history
  def calculate_uptime
    return 0 unless connection_history.is_a?(Array)

    connection_history.sum do |session|
      start_time = Time.parse(session['connected_at']) rescue nil
      end_time = Time.parse(session['disconnected_at']) rescue nil

      if start_time && end_time
        (end_time - start_time).to_i
      else
        0
      end
    end
  end

  # Check if connection is stale (not connected in last 10 minutes)
  def stale?
    return true unless last_connected_at
    last_connected_at < 10.minutes.ago
  end

  # Mark as connected and log in history
  def mark_connected!
    update(
      connected: true,
      last_connected_at: Time.current
    )

    # Add to connection history
    add_to_history('connected')
  end

  # Mark as disconnected and log in history
  def mark_disconnected!
    update(
      connected: false,
      disconnected_at: Time.current
    )

    # Add to connection history
    add_to_history('disconnected')
  end

  # Get connection status as string
  def status
    if connected?
      if stale?
        'stale'
      else
        'connected'
      end
    else
      'disconnected'
    end
  end

  # Get connection display info
  def display_info
    {
      host: host,
      port: port,
      status: status,
      version: version || 'Unknown',
      last_connected: last_connected_at&.iso8601,
      uptime_seconds: connected? && last_connected_at ? (Time.current - last_connected_at).to_i : 0
    }
  end

  private

  def generate_access_token
    self.access_token ||= SecureRandom.hex(32)
  end

  def add_to_history(event_type)
    history = connection_history || []

    # Keep only last 100 events
    history = history.last(99)

    history << {
      event: event_type,
      timestamp: Time.current.iso8601,
      version: version
    }

    update_column(:connection_history, history)
  end
end
