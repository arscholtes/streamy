module Integrations
  class RiotController < ApplicationController
    include IntegrationController

    # Override connect to allow region selection
    def connect
      # Store region preference for callback
      region = params[:region] || 'na1'
      session[:riot_region] = region

      redirect_to oauth_authorize_url, allow_other_host: true
    end

    protected

    def oauth_service_class
      Integrations::RiotOauthService
    end

    def integration_provider
      :riot
    end

    def fetch_user_profile(access_token)
      # Create temporary account to use API client
      region = params[:region] || session[:riot_region] || 'na1'

      temp_account = RiotAccount.new(
        access_token: access_token,
        region: region
      )

      api_client = RiotApiClient.new(temp_account)
      account_info = api_client.fetch_account_info

      {
        puuid: account_info[:puuid],
        game_name: account_info[:gameName],
        tag_line: account_info[:tagLine],
        region: region
      }
    end
  end
end
