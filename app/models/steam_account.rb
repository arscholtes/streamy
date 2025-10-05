# app/models/steam_account.rb
# Steam account integration model
# Stores Steam profile data and OAuth tokens
class SteamAccount < ApplicationRecord
  include IntegrationAccount

  # steam_id is the external_id for Steam
  alias_attribute :external_id, :steam_id

  # Validations
  validates :steam_id, presence: true, uniqueness: true
  validates :persona_name, presence: true

  # OAuth service class
  def oauth_service_class
    Integrations::SteamOauthService
  end

  # Sync service class
  def sync_service_class
    Integrations::SteamSyncService
  end

  # Privacy settings schema
  def self.privacy_settings_schema
    {
      profile: [
        { key: 'show_profile', label: 'Show Steam profile link', default: true },
        { key: 'show_persona_name', label: 'Show display name', default: true },
        { key: 'show_avatar', label: 'Show avatar', default: true },
        { key: 'show_real_name', label: 'Show real name', default: false },
        { key: 'show_country', label: 'Show country', default: true },
        { key: 'show_level', label: 'Show Steam level', default: true }
      ],
      games: [
        { key: 'show_owned_games', label: 'Show owned games', default: true },
        { key: 'show_recent_games', label: 'Show recently played games', default: true },
        { key: 'show_playtime', label: 'Show playtime statistics', default: true },
        { key: 'show_achievements', label: 'Show achievements', default: true }
      ],
      activity: [
        { key: 'show_online_status', label: 'Show online status', default: true },
        { key: 'show_current_game', label: 'Show currently playing game', default: true },
        { key: 'show_last_logoff', label: 'Show last online time', default: false }
      ]
    }
  end

  def default_privacy_settings
    {
      show_profile: true,
      show_persona_name: true,
      show_avatar: true,
      show_real_name: false,
      show_country: true,
      show_level: true,
      show_owned_games: true,
      show_recent_games: true,
      show_playtime: true,
      show_achievements: true,
      show_online_status: true,
      show_current_game: true,
      show_last_logoff: false
    }
  end
end
