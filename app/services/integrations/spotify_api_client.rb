module Integrations
  class SpotifyApiClient < BaseApiClient
    def api_base_url
      'https://api.spotify.com/v1'
    end

    # Get current user's profile
    def fetch_user_profile
      get('/me')
    end

    # Get user's currently playing track
    def fetch_currently_playing
      response = get('/me/player/currently-playing')
      return nil if response.nil?

      {
        track_name: response.dig(:item, :name),
        artist_name: response.dig(:item, :artists, 0, :name),
        album_name: response.dig(:item, :album, :name),
        album_image_url: response.dig(:item, :album, :images, 0, :url),
        is_playing: response[:is_playing],
        progress_ms: response[:progress_ms],
        duration_ms: response.dig(:item, :duration_ms)
      }
    rescue NotFoundError
      # No track currently playing
      nil
    end

    # Get user's recently played tracks
    def fetch_recently_played(limit: 20)
      get('/me/player/recently-played', params: { limit: limit })
    end

    # Get user's top tracks
    def fetch_top_tracks(time_range: 'medium_term', limit: 20)
      get('/me/top/tracks', params: { time_range: time_range, limit: limit })
    end

    # Get user's top artists
    def fetch_top_artists(time_range: 'medium_term', limit: 20)
      get('/me/top/artists', params: { time_range: time_range, limit: limit })
    end

    # Get user's playlists
    def fetch_playlists(limit: 50)
      get('/me/playlists', params: { limit: limit })
    end

    # Get playback state
    def fetch_playback_state
      get('/me/player')
    rescue NotFoundError
      # No active playback
      nil
    end
  end
end
