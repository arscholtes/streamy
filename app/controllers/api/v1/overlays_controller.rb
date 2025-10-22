# app/controllers/api/v1/overlays_controller.rb
# API endpoints for triggering overlay updates from Discord bot or other services
module Api
  module V1
    class OverlaysController < Api::V1::BaseController
      before_action :find_user

      # POST /api/v1/users/:user_id/overlays/trigger_event
      # Trigger an event alert (donation, follow, subscriber)
      def trigger_event
        event_data = {
          id: SecureRandom.uuid,
          type: params[:event_type], # 'donation', 'follow', 'subscriber'
          username: params[:username],
          amount: params[:amount], # For donations
          message: params[:message], # Optional message
          timestamp: Time.current.to_i
        }

        # Add to events cache
        add_event_to_cache(event_data)

        # Broadcast to overlay channel
        broadcast_overlay_update('recent_events')

        render json: {
          success: true,
          event: event_data,
          message: "Event triggered successfully"
        }
      end

      # POST /api/v1/users/:user_id/overlays/trigger_alert
      # Trigger a custom alert
      def trigger_alert
        alert_data = {
          id: SecureRandom.uuid,
          emoji: params[:emoji] || '✨',
          title: params[:title] || 'Alert',
          message: params[:message] || '',
          submessage: params[:submessage] || '',
          duration: params[:duration]&.to_i || 6000,
          timestamp: Time.current.to_i
        }

        # Add to alerts cache
        add_alert_to_cache(alert_data)

        # Broadcast to overlay channel
        broadcast_overlay_update('custom_alert')

        render json: {
          success: true,
          alert: alert_data,
          message: "Alert triggered successfully"
        }
      end

      # POST /api/v1/users/:user_id/overlays/update_data
      # Manually trigger a data refresh for specific overlay
      def update_data
        overlay_type = params[:overlay_type]

        unless valid_overlay_type?(overlay_type)
          render json: { error: "Invalid overlay type" }, status: :bad_request
          return
        end

        broadcast_overlay_update(overlay_type)

        render json: {
          success: true,
          overlay_type: overlay_type,
          message: "Overlay data updated"
        }
      end

      # GET /api/v1/users/:user_id/overlays/events
      # Get recent events (for testing/debugging)
      def events
        events = Rails.cache.fetch("overlay_events:#{@user.id}", expires_in: 5.minutes) do
          []
        end

        render json: { events: events }
      end

      # GET /api/v1/users/:user_id/overlays/alerts
      # Get recent alerts (for testing/debugging)
      def alerts
        alerts = Rails.cache.fetch("overlay_alerts:#{@user.id}", expires_in: 5.minutes) do
          []
        end

        render json: { alerts: alerts }
      end

      # DELETE /api/v1/users/:user_id/overlays/clear_events
      # Clear all events
      def clear_events
        Rails.cache.delete("overlay_events:#{@user.id}")

        render json: {
          success: true,
          message: "Events cleared"
        }
      end

      # DELETE /api/v1/users/:user_id/overlays/clear_alerts
      # Clear all alerts
      def clear_alerts
        Rails.cache.delete("overlay_alerts:#{@user.id}")

        render json: {
          success: true,
          message: "Alerts cleared"
        }
      end

      private

      def find_user
        @user = User.find_by(id: params[:user_id])

        unless @user
          render json: { error: "User not found" }, status: :not_found
        end
      end

      def valid_overlay_type?(type)
        %w[gaming_stats stream_info social_stats recent_events now_playing custom_alert].include?(type)
      end

      def add_event_to_cache(event_data)
        cache_key = "overlay_events:#{@user.id}"
        events = Rails.cache.fetch(cache_key, expires_in: 5.minutes) { [] }
        events << event_data

        # Keep only last 10 events
        events = events.last(10)

        Rails.cache.write(cache_key, events, expires_in: 5.minutes)
      end

      def add_alert_to_cache(alert_data)
        cache_key = "overlay_alerts:#{@user.id}"
        alerts = Rails.cache.fetch(cache_key, expires_in: 5.minutes) { [] }
        alerts << alert_data

        # Keep only last 10 alerts
        alerts = alerts.last(10)

        Rails.cache.write(cache_key, alerts, expires_in: 5.minutes)
      end

      def broadcast_overlay_update(overlay_type = nil)
        # Broadcast update to all connected overlay clients
        OverlayChannel.broadcast_to(@user, {
          type: 'refresh',
          overlay_type: overlay_type,
          timestamp: Time.current.to_i
        })
      end
    end
  end
end
