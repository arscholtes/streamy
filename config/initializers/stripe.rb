# Stripe configuration
# Documentation: https://stripe.com/docs/api

require Rails.root.join('lib/credentials_helper')

stripe_creds = CredentialsHelper.stripe

Rails.configuration.stripe = {
  publishable_key: stripe_creds.publishable_key,
  secret_key: stripe_creds.secret_key,
  webhook_secret: stripe_creds.webhook_secret
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]
Stripe.api_version = '2024-11-20.acacia' # Latest stable version

# Set up logging in development
if Rails.env.development?
  Stripe.log_level = Stripe::LEVEL_INFO
end
