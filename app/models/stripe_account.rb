# app/models/stripe_account.rb
class StripeAccount < ApplicationRecord
  include IntegrationAccount

  alias_attribute :external_id, :stripe_id

  validates :stripe_id, presence: true, uniqueness: true

  def oauth_service_class
    Integrations::StripeOauthService
  end

  def sync_service_class
    Integrations::StripeSyncService
  end

  def self.privacy_settings_schema
    {
      profile: [
        { key: 'show_stripe_connected', label: 'Show Stripe payment enabled status', default: true }
      ],
      monetization: [
        { key: 'accept_donations', label: 'Accept donations', default: true },
        { key: 'accept_subscriptions', label: 'Accept channel subscriptions', default: true }
      ]
    }
  end
end
