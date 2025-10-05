module Integrations
  class GoogleAnalyticsController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "Google Analytics integration coming soon"
      redirect_to settings_path
    end

    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "Google Analytics authorization failed"
        redirect_to settings_path and return
      end

      flash[:success] = "Google Analytics connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("Google Analytics connection error: #{e.message}")
      flash[:error] = "Failed to connect Google Analytics account"
      redirect_to settings_path
    end

    def disconnect
      current_user.google_analytics_account&.destroy
      flash[:success] = "Google Analytics account disconnected"
      redirect_to settings_path
    end

    def sync
      google_analytics_account = current_user.google_analytics_account

      unless google_analytics_account
        flash[:error] = "No Google Analytics account connected"
        redirect_to settings_path and return
      end

      flash[:success] = "Google Analytics sync started"
      redirect_to settings_path
    end
  end
end
