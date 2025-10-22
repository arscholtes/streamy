# app/lib/credentials_helper.rb
# Centralized helper for accessing Rails encrypted credentials
# Usage: CredentialsHelper.stripe.publishable_key
#        CredentialsHelper.discord.client_id
require 'ostruct'

module CredentialsHelper
  class << self
    # Stripe credentials
    def stripe
      fetch_credentials(:stripe)
    end

    # Discord credentials (OAuth + Bot API)
    def discord
      fetch_credentials(:discord)
    end

    # Steam credentials
    def steam
      fetch_credentials(:steam)
    end

    # Battle.net credentials
    def battlenet
      fetch_credentials(:battlenet)
    end

    # Riot Games credentials
    def riot
      fetch_credentials(:riot)
    end

    # Spotify credentials
    def spotify
      fetch_credentials(:spotify)
    end

    # Epic Games credentials
    def epic
      fetch_credentials(:epic)
    end

    # Xbox Live credentials
    def xbox
      fetch_credentials(:xbox)
    end

    # PlayStation Network credentials
    def playstation
      fetch_credentials(:playstation)
    end

    # TikTok credentials
    def tiktok
      fetch_credentials(:tiktok)
    end

    # Instagram credentials
    def instagram
      fetch_credentials(:instagram)
    end

    # Twitch credentials
    def twitch
      fetch_credentials(:twitch)
    end

    # PayPal credentials
    def paypal
      fetch_credentials(:paypal)
    end

    # Google Analytics credentials
    def google_analytics
      fetch_credentials(:google_analytics)
    end

    # OpenAI credentials
    def openai
      fetch_credentials(:openai)
    end

    # YouTube credentials
    def youtube
      fetch_credentials(:youtube)
    end

    # Twitter/X credentials
    def twitter
      fetch_credentials(:twitter)
    end

    # Generic integration method (for dynamic access)
    def integration(provider)
      fetch_credentials(provider.to_sym)
    end

    private

    def fetch_credentials(key)
      credentials = Rails.application.credentials[key]

      if credentials.nil?
        raise MissingCredentialsError, <<~ERROR
          Missing credentials for '#{key}'.

          Please add them to your credentials file by running:
            EDITOR="code --wait" bin/rails credentials:edit

          Then add:

          #{key}:
            client_id: your_#{key}_client_id
            client_secret: your_#{key}_client_secret
        ERROR
      end

      OpenStruct.new(credentials)
    rescue TypeError
      # Credentials might be a string instead of hash (like for simple API keys)
      OpenStruct.new(api_key: credentials)
    end
  end

  # Custom error class for missing credentials
  class MissingCredentialsError < StandardError; end
end