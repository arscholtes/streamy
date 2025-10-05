module Integrations
  class EpicController < ApplicationController
    before_action :require_login

    # GET /integrations/epic/connect
    def connect
      # TODO: Redirect to Epic Games OAuth authorization URL
      flash[:error] = "Epic Games integration coming soon"
      redirect_to settings_path
    end

    # GET /integrations/epic/callback
    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "Epic Games authorization failed"
        redirect_to settings_path and return
      end

      # TODO: Exchange code for tokens
      # TODO: Fetch user profile from Epic Games API
      # TODO: Create/update EpicAccount record
      # TODO: Enqueue sync job

      flash[:success] = "Epic Games connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("Epic Games connection error: #{e.message}")
      flash[:error] = "Failed to connect Epic Games account"
      redirect_to settings_path
    end

    # DELETE /integrations/epic/disconnect
    def disconnect
      current_user.epic_account&.destroy
      flash[:success] = "Epic Games account disconnected"
      redirect_to settings_path
    end

    # POST /integrations/epic/sync
    def sync
      epic_account = current_user.epic_account

      unless epic_account
        flash[:error] = "No Epic Games account connected"
        redirect_to settings_path and return
      end

      # TODO: Enqueue sync job
      flash[:success] = "Epic Games sync started"
      redirect_to settings_path
    end
  end
end
