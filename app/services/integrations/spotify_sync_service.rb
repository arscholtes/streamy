module Integrations
  class SpotifySyncService
    attr_reader :spotify_account

    def initialize(spotify_account)
      @spotify_account = spotify_account
      @api_client = SpotifyApiClient.new(spotify_account)
    end

    def sync!
      ActiveRecord::Base.transaction do
        sync_profile
        sync_currently_playing
      end

      spotify_account.update!(last_synced_at: Time.current)
    rescue Integrations::APIError => e
      Rails.logger.error("Spotify sync failed for account #{spotify_account.id}: #{e.message}")
      raise
    end

    private

    def sync_profile
      profile = @api_client.fetch_user_profile

      spotify_account.update!(
        spotify_id: profile[:id],
        display_name: profile[:display_name],
        email: profile[:email],
        product: profile[:product], # free, premium, etc.
        country: profile[:country],
        follower_count: profile.dig(:followers, :total)
      )
    end

    def sync_currently_playing
      # Store currently playing track in user's profile metadata
      # This could be expanded to a separate table for listening history
      currently_playing = @api_client.fetch_currently_playing

      if currently_playing
        spotify_account.user.update(
          metadata: (spotify_account.user.metadata || {}).merge(
            spotify_currently_playing: {
              track_name: currently_playing[:track_name],
              artist_name: currently_playing[:artist_name],
              album_name: currently_playing[:album_name],
              album_image_url: currently_playing[:album_image_url],
              is_playing: currently_playing[:is_playing],
              updated_at: Time.current
            }
          )
        )
      end
    end
  end
end
