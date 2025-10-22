# frozen_string_literal: true

module Analytics
  class AggregateStreamMetricsJob < ApplicationJob
    queue_as :analytics

    # This job runs every 60 seconds during a live stream to capture metrics
    def perform(stream_id)
      stream = Stream.find_by(id: stream_id)
      return unless stream&.live?

      # Calculate current metrics
      snapshot_data = calculate_snapshot_metrics(stream)

      # Create snapshot
      StreamMetricSnapshot.create!(snapshot_data)

      # Re-enqueue for next snapshot (60 seconds later)
      self.class.set(wait: 60.seconds).perform_later(stream_id)

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to create stream metric snapshot: #{e.message}")
    end

    private

    def calculate_snapshot_metrics(stream)
      now = Time.current
      one_minute_ago = 1.minute.ago

      # Get recent chat messages
      recent_messages = stream.chat_messages.where('created_at >= ?', one_minute_ago)

      # Calculate metrics
      {
        stream_id: stream.id,
        user_id: stream.user_id,
        snapshot_at: now,
        viewer_count: stream.viewer_count,
        chat_messages_count: recent_messages.count,
        chat_rate: recent_messages.count.to_f, # messages per minute
        peak_viewers: calculate_peak_viewers(stream),
        unique_chatters: recent_messages.distinct.count(:user_id),
        metadata: {
          game: current_game_name(stream),
          stream_title: stream.title
        }
      }
    end

    def calculate_peak_viewers(stream)
      # Get the maximum viewer count from snapshots in this stream session
      max_from_snapshots = stream.stream_metric_snapshots
                                 .where('snapshot_at >= ?', stream.updated_at - 1.hour)
                                 .maximum(:viewer_count) || 0

      [stream.viewer_count, max_from_snapshots].max
    end

    def current_game_name(stream)
      active_session = stream.game_sessions.active.first
      active_session&.game_name || 'Unknown'
    end
  end
end
