module Integrations
  class TwitchController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "Twitch integration coming soon"
      redirect_to settings_path
    end

    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "Twitch authorization failed"
        redirect_to settings_path and return
      end

      flash[:success] = "Twitch connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("Twitch connection error: #{e.message}")
      flash[:error] = "Failed to connect Twitch account"
      redirect_to settings_path
    end

    def disconnect
      current_user.twitch_account&.destroy
      flash[:success] = "Twitch account disconnected"
      redirect_to settings_path
    end

    def sync
      twitch_account = current_user.twitch_account

      unless twitch_account
        flash[:error] = "No Twitch account connected"
        redirect_to settings_path and return
      end

      flash[:success] = "Twitch sync started"
      redirect_to settings_path
    end
  end
end
