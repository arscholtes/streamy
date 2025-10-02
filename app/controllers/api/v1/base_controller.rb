module Api
  module V1
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api_request

      private

      def authenticate_api_request
        api_key = request.headers['Authorization']&.sub(/^Bearer /, '')

        unless api_key == ENV['DISCORD_BOT_API_KEY']
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
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
