module Integrations
  class SpotifyController < ApplicationController
    include IntegrationController

    protected

    def oauth_service_class
      Integrations::SpotifyOauthService
    end

    def integration_provider
      :spotify
    end

    def fetch_user_profile(access_token)
      # Create temporary account to use API client
      temp_account = SpotifyAccount.new(access_token: access_token)
      api_client = SpotifyApiClient.new(temp_account)
      profile = api_client.fetch_user_profile

      {
        spotify_id: profile[:id],
        display_name: profile[:display_name],
        email: profile[:email],
        product: profile[:product],
        country: profile[:country],
        follower_count: profile.dig(:followers, :total)
      }
    end
  end
end
