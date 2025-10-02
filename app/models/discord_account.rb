# app/models/discord_account.rb
# Discord account integration model
class DiscordAccount < ApplicationRecord
  include IntegrationAccount

  alias_attribute :external_id, :discord_id

  validates :discord_id, presence: true, uniqueness: true
  validates :username, presence: true

  def oauth_service_class
    Integrations::DiscordOauthService
  end

  def sync_service_class
    Integrations::DiscordSyncService
  end

  def self.privacy_settings_schema
    {
      profile: [
        { key: 'show_username', label: 'Show Discord username', default: true },
        { key: 'show_avatar', label: 'Show Discord avatar', default: true },
        { key: 'show_discriminator', label: 'Show discriminator (#1234)', default: false }
      ],
      servers: [
        { key: 'show_servers', label: 'Show server list', default: true },
        { key: 'show_server_count', label: 'Show number of servers', default: true },
        { key: 'show_roles', label: 'Show server roles', default: false }
      ],
      activity: [
        { key: 'show_online_status', label: 'Show online status', default: true },
        { key: 'show_activity', label: 'Show current activity', default: true }
      ]
    }
  end
end
