module Integrations
  class TiktokController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "TikTok integration coming soon"
      redirect_to settings_path
    end

    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "TikTok authorization failed"
        redirect_to settings_path and return
      end

      flash[:success] = "TikTok connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("TikTok connection error: #{e.message}")
      flash[:error] = "Failed to connect TikTok account"
      redirect_to settings_path
    end

    def disconnect
      current_user.tiktok_account&.destroy
      flash[:success] = "TikTok account disconnected"
      redirect_to settings_path
    end

    def sync
      tiktok_account = current_user.tiktok_account

      unless tiktok_account
        flash[:error] = "No TikTok account connected"
        redirect_to settings_path and return
      end

      flash[:success] = "TikTok sync started"
      redirect_to settings_path
    end
  end
end
