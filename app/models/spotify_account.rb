class SpotifyAccount < ApplicationRecord
  include IntegrationAccount

  validates :spotify_id, presence: true, uniqueness: true

  protected

  def sync_service_class
    Integrations::SpotifySyncService
  end

  def oauth_service_class
    Integrations::SpotifyOauthService
  end

  def external_id_field
    :spotify_id
  end

  def default_privacy_settings
    {
      show_display_name: true,
      show_currently_playing: true,
      show_top_tracks: false,
      show_playlists: false
    }
  end
end
