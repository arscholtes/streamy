module Api
  module V1
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api_request
      before_action :set_cors_headers

      private

      def authenticate_api_request
        api_key = request.headers['Authorization']&.sub(/^Bearer /, '')
        valid_api_key = Rails.application.credentials.discord_bot_api_key

        unless api_key.present? && api_key == valid_api_key
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def set_cors_headers
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type'
      end

      def render_error(message, status: :unprocessable_entity)
        render json: { error: message }, status: status
      end

      def render_success(data, status: :ok)
        render json: data, status: status
      end
    end
  end
end
