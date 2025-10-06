module Integrations
  class BattlenetController < ApplicationController
    include IntegrationController

    # Override connect to allow region selection
    def connect
      # Store region preference for callback
      region = params[:region] || 'us'
      session[:battlenet_region] = region

      redirect_to oauth_authorize_url, allow_other_host: true
    end

    protected

    def oauth_service_class
      Integrations::BattlenetOauthService
    end

    def integration_provider
      :battlenet
    end

    def fetch_user_profile(access_token)
      # Create temporary account to use API client
      # Detect region from params or default to US
      region = params[:region] || session[:battlenet_region] || 'us'

      temp_account = BattlenetAccount.new(
        access_token: access_token,
        region: region
      )

      api_client = BattlenetApiClient.new(temp_account)
      account_info = api_client.fetch_account_info

      {
        battletag: account_info[:battletag],
        region: region
      }
    end

    private

    def oauth_service
      region = params[:region] || session[:battlenet_region] || 'us'
      @oauth_service ||= Integrations::BattlenetOauthService.new(region: region)
    end
  end
end
