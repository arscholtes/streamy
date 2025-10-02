# Service for syncing Stripe account data
module Integrations
  class StripeSyncService
    attr_reader :stripe_account

    def initialize(stripe_account)
      @stripe_account = stripe_account
    end

    # Sync account details from Stripe
    def sync
      account = Stripe::Account.retrieve(stripe_account.stripe_id)

      stripe_account.update!(
        email: account.email,
        account_type: account.type,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        last_synced_at: Time.current
      )

      true
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to sync Stripe account: #{e.message}")
      false
    end

    # Get account balance
    def balance
      balance = Stripe::Balance.retrieve({
        stripe_account: stripe_account.stripe_id
      })

      {
        available: balance.available.map { |b| { amount: b.amount, currency: b.currency } },
        pending: balance.pending.map { |b| { amount: b.amount, currency: b.currency } }
      }
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to get balance: #{e.message}")
      nil
    end

    # Get recent payouts
    def recent_payouts(limit: 10)
      payouts = Stripe::Payout.list({
        limit: limit
      }, {
        stripe_account: stripe_account.stripe_id
      })

      payouts.data.map do |payout|
        {
          id: payout.id,
          amount: payout.amount,
          currency: payout.currency,
          status: payout.status,
          arrival_date: Time.at(payout.arrival_date),
          created: Time.at(payout.created)
        }
      end
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to get payouts: #{e.message}")
      []
    end

    # Check if account needs attention
    def requires_action?
      return true unless stripe_account.charges_enabled
      return true unless stripe_account.payouts_enabled

      # Check if account needs to be updated
      account = Stripe::Account.retrieve(stripe_account.stripe_id)
      account.requirements.currently_due.any? || account.requirements.eventually_due.any?
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to check account requirements: #{e.message}")
      false
    end
  end
end
