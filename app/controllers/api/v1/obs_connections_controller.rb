# app/controllers/api/v1/obs_connections_controller.rb
module Api
  module V1
    class ObsConnectionsController < ApplicationController
      before_action :authenticate_api_key!
      before_action :set_user

      # GET /api/v1/users/:user_id/obs_connection
      # Get user's OBS connection status
      def show
        if @user.obs_connection
          render json: {
            obs_connection: {
              id: @user.obs_connection.id,
              host: @user.obs_connection.host,
              port: @user.obs_connection.port,
              version: @user.obs_connection.version,
              connected: @user.obs_connection.connected,
              last_connected_at: @user.obs_connection.last_connected_at,
              created_at: @user.obs_connection.created_at,
              updated_at: @user.obs_connection.updated_at
            }
          }, status: :ok
        else
          render json: { error: 'OBS connection not found' }, status: :not_found
        end
      end

      # POST /api/v1/users/:user_id/obs_connection
      # Create or update OBS connection
      def create
        obs_connection = @user.obs_connection || @user.build_obs_connection

        obs_connection.assign_attributes(obs_connection_params)
        obs_connection.last_connected_at = Time.current if params[:connected]

        if obs_connection.save
          render json: {
            obs_connection: {
              id: obs_connection.id,
              host: obs_connection.host,
              port: obs_connection.port,
              version: obs_connection.version,
              connected: obs_connection.connected,
              last_connected_at: obs_connection.last_connected_at
            },
            message: 'OBS connection saved successfully'
          }, status: :created
        else
          render json: {
            error: 'Failed to save OBS connection',
            details: obs_connection.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/users/:user_id/obs_connection
      # Update OBS connection status
      def update
        if @user.obs_connection
          # Update connection status
          update_params = obs_connection_params
          update_params[:last_connected_at] = Time.current if params[:connected] == true
          update_params[:disconnected_at] = Time.current if params[:connected] == false

          if @user.obs_connection.update(update_params)
            render json: {
              obs_connection: {
                id: @user.obs_connection.id,
                connected: @user.obs_connection.connected,
                last_connected_at: @user.obs_connection.last_connected_at,
                disconnected_at: @user.obs_connection.disconnected_at
              },
              message: 'OBS connection updated successfully'
            }, status: :ok
          else
            render json: {
              error: 'Failed to update OBS connection',
              details: @user.obs_connection.errors.full_messages
            }, status: :unprocessable_entity
          end
        else
          render json: { error: 'OBS connection not found' }, status: :not_found
        end
      end

      # DELETE /api/v1/users/:user_id/obs_connection
      # Delete OBS connection
      def destroy
        if @user.obs_connection
          @user.obs_connection.destroy
          render json: { message: 'OBS connection deleted successfully' }, status: :ok
        else
          render json: { error: 'OBS connection not found' }, status: :not_found
        end
      end

      # GET /api/v1/users/:user_id/obs_connection/stats
      # Get OBS connection statistics
      def stats
        if @user.obs_connection
          # Calculate connection stats
          total_uptime = @user.obs_connection.calculate_uptime
          connection_count = @user.obs_connection.connection_history&.count || 0

          render json: {
            stats: {
              total_connections: connection_count,
              total_uptime_seconds: total_uptime,
              average_session_duration: connection_count > 0 ? (total_uptime / connection_count).round : 0,
              last_connected_at: @user.obs_connection.last_connected_at,
              disconnected_at: @user.obs_connection.disconnected_at,
              currently_connected: @user.obs_connection.connected
            }
          }, status: :ok
        else
          render json: { error: 'OBS connection not found' }, status: :not_found
        end
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def obs_connection_params
        params.permit(:host, :port, :password_encrypted, :version, :connected, :connection_name)
      end

      def authenticate_api_key!
        api_key = request.headers['X-API-Key'] || params[:api_key]

        unless api_key == ENV['DISCORD_BOT_API_KEY']
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end
