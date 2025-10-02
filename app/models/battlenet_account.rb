# app/models/battlenet_account.rb
class BattlenetAccount < ApplicationRecord
  include IntegrationAccount

  alias_attribute :external_id, :battletag

  validates :battletag, presence: true, uniqueness: true
  validates :region, presence: true

  def oauth_service_class
    Integrations::BattlenetOauthService
  end

  def sync_service_class
    Integrations::BattlenetSyncService
  end

  def self.privacy_settings_schema
    {
      profile: [
        { key: 'show_battletag', label: 'Show BattleTag', default: true },
        { key: 'show_region', label: 'Show region', default: true }
      ],
      games: [
        { key: 'show_wow_characters', label: 'Show WoW characters', default: true },
        { key: 'show_overwatch_stats', label: 'Show Overwatch stats', default: true },
        { key: 'show_diablo_characters', label: 'Show Diablo characters', default: true }
      ]
    }
  end
end
