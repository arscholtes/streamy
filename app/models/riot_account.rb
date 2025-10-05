# app/models/riot_account.rb
class RiotAccount < ApplicationRecord
  include IntegrationAccount

  alias_attribute :external_id, :puuid

  validates :puuid, presence: true, uniqueness: true
  validates :game_name, presence: true

  def oauth_service_class
    Integrations::RiotOauthService
  end

  def sync_service_class
    Integrations::RiotSyncService
  end

  def self.privacy_settings_schema
    {
      profile: [
        { key: 'show_game_name', label: 'Show Riot ID', default: true },
        { key: 'show_tag_line', label: 'Show tag line', default: true }
      ],
      lol: [
        { key: 'show_lol_rank', label: 'Show League of Legends rank', default: true },
        { key: 'show_lol_champions', label: 'Show champion mastery', default: true },
        { key: 'show_lol_match_history', label: 'Show match history', default: true }
      ],
      valorant: [
        { key: 'show_valorant_rank', label: 'Show Valorant rank', default: true },
        { key: 'show_valorant_agents', label: 'Show agent stats', default: true }
      ]
    }
  end

  def default_privacy_settings
    {
      show_game_name: true,
      show_tag_line: true,
      show_lol_rank: true,
      show_lol_champions: true,
      show_lol_match_history: true,
      show_valorant_rank: true,
      show_valorant_agents: true
    }
  end
end
