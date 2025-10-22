# frozen_string_literal: true

module Analytics
  class RecordEventJob < ApplicationJob
    queue_as :analytics

    def perform(user_id:, event_type:, event_data:, occurred_at:, stream_id: nil)
      AnalyticsEvent.create!(
        user_id: user_id,
        stream_id: stream_id,
        event_type: event_type,
        event_data: event_data,
        occurred_at: occurred_at
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to record analytics event: #{e.message}")
      # Don't re-raise - we don't want analytics failures to break the app
    end
  end
end
