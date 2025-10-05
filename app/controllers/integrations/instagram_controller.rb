module Integrations
  class InstagramController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "Instagram integration coming soon"
      redirect_to settings_path
    end

    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "Instagram authorization failed"
        redirect_to settings_path and return
      end

      flash[:success] = "Instagram connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("Instagram connection error: #{e.message}")
      flash[:error] = "Failed to connect Instagram account"
      redirect_to settings_path
    end

    def disconnect
      current_user.instagram_account&.destroy
      flash[:success] = "Instagram account disconnected"
      redirect_to settings_path
    end

    def sync
      instagram_account = current_user.instagram_account

      unless instagram_account
        flash[:error] = "No Instagram account connected"
        redirect_to settings_path and return
      end

      flash[:success] = "Instagram sync started"
      redirect_to settings_path
    end
  end
end
