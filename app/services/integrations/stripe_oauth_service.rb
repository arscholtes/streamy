# Service for handling Stripe Connect OAuth flow
module Integrations
  class StripeOauthService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # Generate Stripe Connect OAuth URL for onboarding
    def authorization_url(redirect_uri:)
      params = {
        client_id: Rails.configuration.stripe[:connect_client_id],
        state: generate_state_token,
        redirect_uri: redirect_uri,
        'stripe_user[email]': user.email,
        'stripe_user[business_type]': 'individual'
      }

      "https://connect.stripe.com/express/oauth/authorize?#{params.to_query}"
    end

    # Exchange authorization code for access token
    def connect_account(code:)
      response = Stripe::OAuth.token({
        grant_type: 'authorization_code',
        code: code
      })

      # Get account details
      account = Stripe::Account.retrieve(response.stripe_user_id)

      # Create or update StripeAccount
      stripe_account = user.stripe_account || user.build_stripe_account

      stripe_account.update!(
        stripe_id: account.id,
        email: account.email,
        account_type: account.type,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        access_token: response.access_token,
        refresh_token: response.refresh_token,
        last_synced_at: Time.current
      )

      stripe_account
    rescue Stripe::OAuth::OAuthError => e
      Rails.logger.error("Stripe OAuth error: #{e.message}")
      raise
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error during connect: #{e.message}")
      raise
    end

    # Disconnect Stripe account
    def disconnect_account
      stripe_account = user.stripe_account
      return false unless stripe_account

      # Deauthorize the account in Stripe
      Stripe::OAuth.deauthorize({
        client_id: Rails.configuration.stripe[:connect_client_id],
        stripe_user_id: stripe_account.stripe_id
      })

      # Delete local record
      stripe_account.destroy

      true
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to disconnect Stripe: #{e.message}")
      false
    end

    # Refresh access token if needed
    def refresh_access_token
      stripe_account = user.stripe_account
      return false unless stripe_account&.refresh_token

      response = Stripe::OAuth.token({
        grant_type: 'refresh_token',
        refresh_token: stripe_account.refresh_token
      })

      stripe_account.update!(
        access_token: response.access_token,
        last_synced_at: Time.current
      )

      true
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to refresh token: #{e.message}")
      false
    end

    # Create Express account link for onboarding/updating
    def create_account_link(return_url:, refresh_url:)
      stripe_account = user.stripe_account
      return nil unless stripe_account

      account_link = Stripe::AccountLink.create({
        account: stripe_account.stripe_id,
        refresh_url: refresh_url,
        return_url: return_url,
        type: 'account_onboarding'
      })

      account_link.url
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to create account link: #{e.message}")
      nil
    end

    # Check if account is fully onboarded
    def onboarding_complete?
      stripe_account = user.stripe_account
      return false unless stripe_account

      stripe_account.charges_enabled && stripe_account.payouts_enabled
    end

    # Get account dashboard login link
    def create_login_link
      stripe_account = user.stripe_account
      return nil unless stripe_account

      login_link = Stripe::Account.create_login_link(stripe_account.stripe_id)
      login_link.url
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to create login link: #{e.message}")
      nil
    end

    private

    def generate_state_token
      SecureRandom.urlsafe_base64(32)
    end
  end
end
