# frozen_string_literal: true

module Analytics
  class EventCollector
    class << self
      # Track stream events
      def track_stream_start(user:, stream:, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'stream_start',
          event_data: metadata.merge(
            stream_id: stream.id,
            title: stream.title
          )
        )
      end

      def track_stream_end(user:, stream:, duration_seconds: 0, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'stream_end',
          event_data: metadata.merge(
            stream_id: stream.id,
            duration_seconds: duration_seconds
          )
        )
      end

      # Track viewer activity
      def track_viewer_join(user:, stream: nil, viewer_username: nil, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'viewer_join',
          event_data: metadata.merge(
            viewer_username: viewer_username
          ).compact
        )
      end

      def track_viewer_leave(user:, stream: nil, viewer_username: nil, watch_time_seconds: 0, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'viewer_leave',
          event_data: metadata.merge(
            viewer_username: viewer_username,
            watch_time_seconds: watch_time_seconds
          ).compact
        )
      end

      # Track engagement events
      def track_chat_message(user:, stream: nil, message_length: 0, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'chat_message',
          event_data: metadata.merge(
            message_length: message_length
          )
        )
      end

      def track_follower_gained(user:, follower_username: nil, metadata: {})
        record_event(
          user: user,
          stream: nil,
          event_type: 'follower_gained',
          event_data: metadata.merge(
            follower_username: follower_username
          ).compact
        )
      end

      # Track milestone events
      def track_achievement_unlocked(user:, achievement_id:, achievement_name:, metadata: {})
        record_event(
          user: user,
          stream: nil,
          event_type: 'achievement_unlocked',
          event_data: metadata.merge(
            achievement_id: achievement_id,
            achievement_name: achievement_name
          )
        )
      end

      def track_milestone_reached(user:, milestone_type:, milestone_value:, metadata: {})
        record_event(
          user: user,
          stream: nil,
          event_type: 'milestone_reached',
          event_data: metadata.merge(
            milestone_type: milestone_type,
            milestone_value: milestone_value
          )
        )
      end

      # Track game changes
      def track_game_changed(user:, stream:, game_name:, platform: nil, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'game_changed',
          event_data: metadata.merge(
            game_name: game_name,
            platform: platform
          ).compact
        )
      end

      # Track subscription events
      def track_subscription_started(user:, subscriber_username: nil, tier: nil, metadata: {})
        record_event(
          user: user,
          stream: nil,
          event_type: 'subscription_started',
          event_data: metadata.merge(
            subscriber_username: subscriber_username,
            tier: tier
          ).compact
        )
      end

      def track_subscription_ended(user:, subscriber_username: nil, metadata: {})
        record_event(
          user: user,
          stream: nil,
          event_type: 'subscription_ended',
          event_data: metadata.merge(
            subscriber_username: subscriber_username
          ).compact
        )
      end

      # Track donation events
      def track_donation_received(user:, amount:, donor_username: nil, message: nil, metadata: {})
        record_event(
          user: user,
          stream: nil,
          event_type: 'donation_received',
          event_data: metadata.merge(
            amount: amount,
            donor_username: donor_username,
            message: message
          ).compact
        )
      end

      # Track raid events
      def track_raid_received(user:, stream:, raider_username:, viewer_count:, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'raid_received',
          event_data: metadata.merge(
            raider_username: raider_username,
            viewer_count: viewer_count
          )
        )
      end

      def track_raid_sent(user:, stream:, target_username:, viewer_count:, metadata: {})
        record_event(
          user: user,
          stream: stream,
          event_type: 'raid_sent',
          event_data: metadata.merge(
            target_username: target_username,
            viewer_count: viewer_count
          )
        )
      end

      private

      def record_event(user:, stream: nil, event_type:, event_data:, occurred_at: nil)
        # Queue the event recording as a background job for performance
        Analytics::RecordEventJob.perform_later(
          user_id: user.id,
          stream_id: stream&.id,
          event_type: event_type,
          event_data: event_data,
          occurred_at: occurred_at || Time.current
        )
      end
    end
  end
end
