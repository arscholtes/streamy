module Integrations
  class XboxController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "Xbox Live integration coming soon"
      redirect_to settings_path
    end

    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "Xbox Live authorization failed"
        redirect_to settings_path and return
      end

      flash[:success] = "Xbox Live connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("Xbox Live connection error: #{e.message}")
      flash[:error] = "Failed to connect Xbox Live account"
      redirect_to settings_path
    end

    def disconnect
      current_user.xbox_account&.destroy
      flash[:success] = "Xbox Live account disconnected"
      redirect_to settings_path
    end

    def sync
      xbox_account = current_user.xbox_account

      unless xbox_account
        flash[:error] = "No Xbox Live account connected"
        redirect_to settings_path and return
      end

      flash[:success] = "Xbox Live sync started"
      redirect_to settings_path
    end
  end
end
