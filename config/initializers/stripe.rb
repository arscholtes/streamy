# Stripe configuration
# Documentation: https://stripe.com/docs/api

require Rails.root.join('lib/credentials_helper')

Rails.configuration.stripe = {
  publishable_key: CredentialsHelper.stripe.publishable_key,
  secret_key: CredentialsHelper.stripe.secret_key,
  signing_secret: CredentialsHelper.stripe.signing_secret,
  connect_client_id: CredentialsHelper.stripe.connect_client_id
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]
Stripe.api_version = '2024-11-20.acacia' # Latest stable version

# Set up logging in development
if Rails.env.development?
  Stripe.log_level = Stripe::LEVEL_INFO
end
