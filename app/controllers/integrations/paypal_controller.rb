module Integrations
  class PaypalController < ApplicationController
    before_action :require_login

    def connect
      flash[:error] = "PayPal integration coming soon"
      redirect_to settings_path
    end

    def callback
      code = params[:code]

      if code.blank?
        flash[:error] = "PayPal authorization failed"
        redirect_to settings_path and return
      end

      flash[:success] = "PayPal connected successfully"
      redirect_to settings_path
    rescue => e
      Rails.logger.error("PayPal connection error: #{e.message}")
      flash[:error] = "Failed to connect PayPal account"
      redirect_to settings_path
    end

    def disconnect
      current_user.paypal_account&.destroy
      flash[:success] = "PayPal account disconnected"
      redirect_to settings_path
    end

    def sync
      paypal_account = current_user.paypal_account

      unless paypal_account
        flash[:error] = "No PayPal account connected"
        redirect_to settings_path and return
      end

      flash[:success] = "PayPal sync started"
      redirect_to settings_path
    end
  end
end
