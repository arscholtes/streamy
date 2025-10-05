module Integrations
  class OpenaiController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "OpenAI integration coming soon"
      redirect_to settings_path
    end

    def create
      api_key = params[:api_key]
      organization_id = params[:organization_id]

      if api_key.blank?
        flash[:error] = "API key is required"
        redirect_to settings_path and return
      end

      openai_integration = current_user.openai_integration || current_user.build_openai_integration
      openai_integration.update!(
        api_key: api_key,
        organization_id: organization_id,
        usage_limit: 1000,
        usage_count: 0
      )

      flash[:success] = "OpenAI API key configured successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("OpenAI configuration error: #{e.message}")
      flash[:error] = "Failed to configure OpenAI API"
      redirect_to settings_path
    end

    def disconnect
      current_user.openai_integration&.destroy
      flash[:success] = "OpenAI integration disconnected"
      redirect_to settings_path
    end
  end
end
