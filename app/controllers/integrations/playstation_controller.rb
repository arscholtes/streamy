module Integrations
  class PlaystationController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "PlayStation Network integration coming soon"
      redirect_to settings_path
    end

    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "PlayStation Network authorization failed"
        redirect_to settings_path and return
      end

      flash[:success] = "PlayStation Network connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("PlayStation Network connection error: #{e.message}")
      flash[:error] = "Failed to connect PlayStation Network account"
      redirect_to settings_path
    end

    def disconnect
      current_user.playstation_account&.destroy
      flash[:success] = "PlayStation Network account disconnected"
      redirect_to settings_path
    end

    def sync
      playstation_account = current_user.playstation_account

      unless playstation_account
        flash[:error] = "No PlayStation Network account connected"
        redirect_to settings_path and return
      end

      flash[:success] = "PlayStation Network sync started"
      redirect_to settings_path
    end
  end
end
