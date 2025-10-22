# frozen_string_literal: true

module Analytics
  class GenerateDailySummaryJob < ApplicationJob
    queue_as :analytics

    # This job runs at midnight to generate the previous day's summary
    def perform(user_id, date = Date.yesterday)
      user = User.find_by(id: user_id)
      return unless user

      # Check if summary already exists
      existing = DailyStreamSummary.find_by(user_id: user_id, summary_date: date)
      return if existing

      summary_data = calculate_daily_metrics(user, date)

      DailyStreamSummary.create!(summary_data)

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to create daily stream summary for user #{user_id}: #{e.message}")
    end

    private

    def calculate_daily_metrics(user, date)
      start_time = date.beginning_of_day
      end_time = date.end_of_day

      # Get streams for the day
      streams = user.streams.where(created_at: start_time..end_time)
      live_streams = streams.where(status: 'live')

      # Get snapshots for the day
      snapshots = user.stream_metric_snapshots.where(snapshot_at: start_time..end_time)

      # Get events for the day
      events = user.analytics_events.where(occurred_at: start_time..end_time)

      # Calculate streaming metrics
      stream_sessions = calculate_stream_sessions(streams, events)
      total_stream_time = stream_sessions.sum { |s| s[:duration_seconds] }

      # Calculate engagement metrics
      chat_metrics = calculate_chat_metrics(snapshots, events)

      # Calculate growth metrics
      growth_metrics = calculate_growth_metrics(user, events, date)

      # Get top games
      top_games = calculate_top_games(user, start_time, end_time)

      {
        user_id: user.id,
        summary_date: date,

        # Streaming metrics
        total_stream_time_seconds: total_stream_time,
        stream_count: stream_sessions.count,
        peak_viewers: snapshots.maximum(:peak_viewers) || 0,
        avg_viewers: (snapshots.average(:viewer_count)&.round || 0),
        unique_viewers: snapshots.maximum(:unique_chatters) || 0,

        # Engagement metrics
        total_chat_messages: chat_metrics[:total_messages],
        unique_chatters: chat_metrics[:unique_chatters],
        avg_chat_rate: chat_metrics[:avg_rate],

        # Growth metrics
        follower_count: growth_metrics[:follower_count],
        followers_gained: growth_metrics[:followers_gained],
        followers_lost: growth_metrics[:followers_lost],

        # Revenue metrics
        subscriptions_gained: events.by_type('subscription_started').count,
        revenue_earned: calculate_revenue(events),

        # Additional data
        top_games: top_games,
        metadata: {
          generated_at: Time.current,
          snapshots_analyzed: snapshots.count,
          events_analyzed: events.count
        }
      }
    end

    def calculate_stream_sessions(streams, events)
      stream_starts = events.by_type('stream_start')
      stream_ends = events.by_type('stream_end')

      stream_starts.map do |start_event|
        end_event = stream_ends.where('occurred_at > ?', start_event.occurred_at).first

        {
          started_at: start_event.occurred_at,
          ended_at: end_event&.occurred_at || Time.current,
          duration_seconds: end_event ? (end_event.occurred_at - start_event.occurred_at).to_i : 0
        }
      end
    end

    def calculate_chat_metrics(snapshots, events)
      chat_events = events.by_type('chat_message')

      {
        total_messages: chat_events.count,
        unique_chatters: snapshots.sum(:unique_chatters),
        avg_rate: (snapshots.average(:chat_rate)&.round(2) || 0.0)
      }
    end

    def calculate_growth_metrics(user, events, date)
      followers_gained = events.by_type('follower_gained').count

      # Get follower count at end of day
      # This is a simplified version - in production you'd track actual follower counts
      previous_summary = user.daily_stream_summaries.where('summary_date < ?', date).order(summary_date: :desc).first
      previous_count = previous_summary&.follower_count || 0

      {
        follower_count: previous_count + followers_gained,
        followers_gained: followers_gained,
        followers_lost: 0 # Placeholder - track this if you have unfollows
      }
    end

    def calculate_top_games(user, start_time, end_time)
      game_sessions = user.game_sessions.where(started_at: start_time..end_time)

      game_sessions.group_by(&:game_name).map do |game_name, sessions|
        total_time = sessions.sum do |session|
          if session.ended_at
            session.duration
          else
            Time.current - session.started_at
          end
        end

        {
          name: game_name,
          platform: sessions.first.platform,
          total_time_seconds: total_time.to_i
        }
      end.sort_by { |g| -g[:total_time_seconds] }.take(5)
    end

    def calculate_revenue(events)
      donation_events = events.by_type('donation_received')
      donation_events.sum { |e| e.event_data['amount'].to_f }
    end
  end
end
