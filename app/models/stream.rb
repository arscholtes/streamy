class Stream < ApplicationRecord
  belongs_to :user
  has_many :chat_messages, dependent: :destroy
  # TODO: Uncomment when GameSession model is created
  # has_many :game_sessions, dependent: :destroy

  # Callbacks
  after_commit :start_game_detection, on: :update, if: :just_went_live?
  # TODO: Uncomment when GameSession model is created
  # after_commit :end_game_sessions, on: :update, if: :just_went_offline?

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :status, presence: true, inclusion: { in: %w[live offline] }

  # Scopes
  scope :live, -> { where(status: 'live') }
  scope :offline, -> { where(status: 'offline') }
  scope :recent, -> { order(updated_at: :desc) }
  scope :popular, -> { live.order(viewer_count: :desc) } # Will work when we add viewer_count

  # Search by title or username
  scope :search, ->(query) {
    return all if query.blank?
    joins(:user).where(
      'streams.title LIKE ? OR users.username LIKE ?',
      "%#{query}%", "%#{query}%"
    )
  }

  # Instance methods
  def live?
    status == 'live'
  end

  def offline?
    status == 'offline'
  end

  # Get viewer count (mock for now, would come from streaming server)
  def viewer_count
    return 0 unless live?
    # Mock data - in production this would query your streaming server
    rand(10..500)
  end

  # Generate thumbnail URL (mock for now)
  def thumbnail_url
    # In production, this would return actual stream thumbnail
    # For now, return a placeholder based on stream status
    if live?
      "https://via.placeholder.com/320x180/8B5CF6/FFFFFF?text=LIVE"
    else
      "https://via.placeholder.com/320x180/1a1f3a/FFFFFF?text=OFFLINE"
    end
  end

  # Playback URL for video player
  def playback_url
    return nil unless live?
    playback_path || "http://localhost:8080/hls/#{stream_key}.m3u8"
  end

  private

  # Check if stream just transitioned to live
  def just_went_live?
    saved_change_to_status? && status == 'live' && status_before_last_save == 'offline'
  end

  # Check if stream just transitioned to offline
  def just_went_offline?
    saved_change_to_status? && status == 'offline' && status_before_last_save == 'live'
  end

  # Start game detection when stream goes live
  def start_game_detection
    return unless user.steam_account.present?

    # Start the detection job (it will re-enqueue itself every 30 seconds)
    Integrations::DetectCurrentGameJob.perform_later(id)
  end

  # End all active game sessions when stream goes offline
  # TODO: Uncomment when GameSession model is created
  # def end_game_sessions
  #   game_sessions.where(ended_at: nil).update_all(ended_at: Time.current)
  # end
end
