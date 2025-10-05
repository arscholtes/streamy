# app/jobs/integrations/detect_current_game_job.rb
# Background job to detect what game a streamer is currently playing
# Runs every 30 seconds during a live stream

module Integrations
  class DetectCurrentGameJob < ApplicationJob
    queue_as :high_priority

    # Detect game for a specific stream
    def perform(stream_id)
      stream = Stream.find(stream_id)
      return unless stream.live?

      user = stream.user
      return unless user.steam_account.present?

      steam_account = user.steam_account
      detect_and_update_current_game(stream, steam_account)

      # Re-enqueue if stream is still live
      if stream.reload.live?
        DetectCurrentGameJob.set(wait: 30.seconds).perform_later(stream_id)
      end
    rescue ActiveRecord::RecordNotFound
      # Stream or user deleted, stop job
      Rails.logger.info("Stream #{stream_id} not found, stopping game detection")
    rescue => e
      Rails.logger.error("Game detection error for stream #{stream_id}: #{e.message}")
      # Don't re-raise, just log and continue
    end

    private

    def detect_and_update_current_game(stream, steam_account)
      api_client = SteamApiClient.new(steam_account)

      # Get recently played games (last 2 weeks)
      recent_data = api_client.get_recent_games(count: 1)
      return unless recent_data && recent_data['games']&.any?

      most_recent_game = recent_data['games'].first

      # Check if this game was played very recently (within last 5 minutes)
      last_played_minutes_ago = (Time.now.to_i - most_recent_game['rtime_last_played']) / 60
      return if last_played_minutes_ago > 5

      # Find or create the game in our database
      steam_game = steam_account.steam_games.find_or_create_by(app_id: most_recent_game['appid']) do |game|
        game.name = most_recent_game['name']
        game.img_icon_url = most_recent_game['img_icon_url']
      end

      # Create or update game session
      current_session = GameSession.find_by(
        user: stream.user,
        stream: stream,
        game_id: steam_game.app_id.to_s,
        platform: 'steam',
        ended_at: nil
      )

      if current_session
        # Session already exists, touch it to show activity
        current_session.touch
      else
        # End any other active sessions for this stream
        GameSession.where(user: stream.user, stream: stream, ended_at: nil)
                   .update_all(ended_at: Time.current)

        # Create new session
        GameSession.create!(
          user: stream.user,
          stream: stream,
          platform: 'steam',
          game_name: steam_game.name,
          game_id: steam_game.app_id.to_s,
          started_at: Time.current,
          metadata: {
            steam_app_id: steam_game.app_id,
            game_icon_url: steam_game.img_icon_url
          }
        )

        # Update stream with current game info (optional)
        update_stream_metadata(stream, steam_game)
      end
    end

    def update_stream_metadata(stream, game)
      # You could update the stream title or category here if desired
      # For now, we'll just log it
      Rails.logger.info("Stream #{stream.id} detected game: #{game.name}")
    end
  end
end
