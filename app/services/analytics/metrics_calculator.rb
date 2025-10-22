# frozen_string_literal: true

module Analytics
  class MetricsCalculator
    attr_reader :user, :period_start, :period_end

    def initialize(user, period_start: 30.days.ago.to_date, period_end: Date.today)
      @user = user
      @period_start = period_start
      @period_end = period_end
    end

    # Main method to calculate all metrics
    def calculate_all
      {
        growth: calculate_growth_metrics,
        engagement: calculate_engagement_metrics,
        consistency: calculate_consistency_metrics,
        performance: calculate_performance_metrics,
        content: calculate_content_metrics
      }
    end

    # Calculate growth-related metrics
    def calculate_growth_metrics
      summaries = daily_summaries
      return default_growth_metrics if summaries.empty?

      current_week = summaries.where('summary_date >= ?', 7.days.ago.to_date)
      previous_week = summaries.where('summary_date >= ? AND summary_date < ?', 14.days.ago.to_date, 7.days.ago.to_date)

      {
        follower_growth_rate: calculate_growth_rate(
          current_week.sum(:followers_gained),
          previous_week.sum(:followers_gained)
        ),
        viewer_growth_rate: calculate_growth_rate(
          current_week.average(:avg_viewers)&.round || 0,
          previous_week.average(:avg_viewers)&.round || 0
        ),
        total_followers_gained: summaries.sum(:followers_gained),
        avg_viewers_trend: calculate_trend_direction(summaries, :avg_viewers),
        peak_viewers_trend: calculate_trend_direction(summaries, :peak_viewers)
      }
    end

    # Calculate engagement-related metrics
    def calculate_engagement_metrics
      summaries = daily_summaries
      return default_engagement_metrics if summaries.empty?

      total_viewers = summaries.sum(:unique_viewers)
      total_chatters = summaries.sum(:unique_chatters)

      {
        engagement_score: calculate_engagement_score(summaries),
        chat_participation_rate: total_viewers.zero? ? 0 : (total_chatters.to_f / total_viewers * 100).round(2),
        avg_chat_rate: (summaries.average(:avg_chat_rate)&.round(2) || 0),
        total_chat_messages: summaries.sum(:total_chat_messages),
        messages_per_viewer: total_viewers.zero? ? 0 : (summaries.sum(:total_chat_messages).to_f / total_viewers).round(2)
      }
    end

    # Calculate streaming consistency metrics
    def calculate_consistency_metrics
      summaries = daily_summaries
      return default_consistency_metrics if summaries.empty?

      days_in_period = (period_end - period_start).to_i + 1
      days_streamed = summaries.where('stream_count > 0').count

      {
        consistency_score: (days_streamed.to_f / days_in_period * 100).round(2),
        days_streamed: days_streamed,
        total_days: days_in_period,
        avg_streams_per_day: (summaries.average(:stream_count)&.round(2) || 0),
        avg_stream_duration_hours: calculate_avg_stream_duration(summaries),
        total_hours_streamed: (summaries.sum(:total_stream_time_seconds) / 3600.0).round(2),
        longest_stream_hours: (summaries.maximum(:total_stream_time_seconds).to_i / 3600.0).round(2)
      }
    end

    # Calculate performance metrics
    def calculate_performance_metrics
      summaries = daily_summaries
      snapshots = stream_snapshots

      return default_performance_metrics if summaries.empty?

      current_week = summaries.where('summary_date >= ?', 7.days.ago.to_date)
      previous_week = summaries.where('summary_date >= ? AND summary_date < ?', 14.days.ago.to_date, 7.days.ago.to_date)

      {
        avg_viewers_current: (current_week.average(:avg_viewers)&.round || 0),
        avg_viewers_previous: (previous_week.average(:avg_viewers)&.round || 0),
        peak_viewers_current: current_week.maximum(:peak_viewers) || 0,
        peak_viewers_previous: previous_week.maximum(:peak_viewers) || 0,
        best_stream_day: find_best_stream_day(summaries),
        best_stream_time: find_best_stream_time(snapshots),
        viewer_retention_score: calculate_viewer_retention(snapshots)
      }
    end

    # Calculate content-related metrics
    def calculate_content_metrics
      summaries = daily_summaries
      game_sessions = user.game_sessions.where(started_at: period_start.beginning_of_day..period_end.end_of_day)

      top_games = calculate_top_games_performance(game_sessions)

      {
        total_games_played: game_sessions.select(:game_name).distinct.count,
        top_games: top_games,
        most_played_game: top_games.first,
        best_performing_game: find_best_performing_game(top_games, summaries)
      }
    end

    private

    def daily_summaries
      @daily_summaries ||= user.daily_stream_summaries.for_date_range(period_start, period_end)
    end

    def stream_snapshots
      @stream_snapshots ||= user.stream_metric_snapshots.between(
        period_start.beginning_of_day,
        period_end.end_of_day
      )
    end

    def calculate_growth_rate(current, previous)
      return 0 if previous.zero? && current.zero?
      return 100.0 if previous.zero? && current.positive?

      ((current - previous).to_f / previous * 100).round(2)
    end

    def calculate_trend_direction(summaries, metric)
      values = summaries.chronological.pluck(metric)
      return 'stable' if values.size < 2

      # Simple linear regression slope
      n = values.size
      x_values = (1..n).to_a
      x_mean = x_values.sum.to_f / n
      y_mean = values.sum.to_f / n

      numerator = x_values.zip(values).sum { |x, y| (x - x_mean) * (y - y_mean) }
      denominator = x_values.sum { |x| (x - x_mean)**2 }

      slope = denominator.zero? ? 0 : numerator / denominator

      if slope > 0.1
        'growing'
      elsif slope < -0.1
        'declining'
      else
        'stable'
      end
    end

    def calculate_engagement_score(summaries)
      # Engagement score combines chat rate and viewer participation
      avg_chat_rate = summaries.average(:avg_chat_rate) || 0
      avg_viewers = summaries.average(:avg_viewers) || 1

      # Normalize: more than 1 message per minute per 10 viewers = 100 score
      raw_score = (avg_chat_rate / (avg_viewers / 10.0)) * 100
      [raw_score, 100].min.round(2)
    end

    def calculate_avg_stream_duration(summaries)
      streams_with_time = summaries.where('total_stream_time_seconds > 0')
      return 0 if streams_with_time.empty?

      avg_seconds = streams_with_time.average(:total_stream_time_seconds) || 0
      (avg_seconds / 3600.0).round(2)
    end

    def find_best_stream_day(summaries)
      best_day = summaries.order(peak_viewers: :desc, avg_viewers: :desc).first
      best_day&.summary_date&.strftime('%A') || 'N/A'
    end

    def find_best_stream_time(snapshots)
      return 'N/A' if snapshots.empty?

      # Group by hour and find average viewers for each hour
      hourly_performance = snapshots.group_by { |s| s.snapshot_at.hour }
                                    .transform_values { |snaps| snaps.sum(&:viewer_count) / snaps.size.to_f }

      best_hour = hourly_performance.max_by { |_, avg| avg }&.first || 12

      "#{best_hour}:00 - #{best_hour + 1}:00"
    end

    def calculate_viewer_retention(snapshots)
      return 0 if snapshots.empty?

      # Group snapshots by stream and calculate retention
      streams = snapshots.group_by(&:stream_id)

      retention_scores = streams.map do |_, stream_snapshots|
        next 0 if stream_snapshots.size < 2

        sorted = stream_snapshots.sort_by(&:snapshot_at)
        initial_viewers = sorted.first.viewer_count

        next 0 if initial_viewers.zero?

        avg_viewers = sorted.sum(&:viewer_count) / sorted.size.to_f
        (avg_viewers / initial_viewers * 100).round(2)
      end

      (retention_scores.sum / retention_scores.size.to_f).round(2)
    end

    def calculate_top_games_performance(game_sessions)
      game_sessions.group_by(&:game_name).map do |game_name, sessions|
        total_time_seconds = sessions.sum { |s| s.duration || 0 }

        {
          name: game_name,
          platform: sessions.first.platform,
          sessions_count: sessions.count,
          total_hours: (total_time_seconds / 3600.0).round(2),
          avg_duration_hours: sessions.count.zero? ? 0 : (total_time_seconds / sessions.count.to_f / 3600.0).round(2)
        }
      end.sort_by { |g| -g[:total_hours] }
    end

    def find_best_performing_game(top_games, summaries)
      # This is simplified - in production you'd correlate game sessions with viewer counts
      top_games.first
    end

    # Default empty metrics
    def default_growth_metrics
      { follower_growth_rate: 0, viewer_growth_rate: 0, total_followers_gained: 0,
        avg_viewers_trend: 'stable', peak_viewers_trend: 'stable' }
    end

    def default_engagement_metrics
      { engagement_score: 0, chat_participation_rate: 0, avg_chat_rate: 0,
        total_chat_messages: 0, messages_per_viewer: 0 }
    end

    def default_consistency_metrics
      { consistency_score: 0, days_streamed: 0, total_days: 0, avg_streams_per_day: 0,
        avg_stream_duration_hours: 0, total_hours_streamed: 0, longest_stream_hours: 0 }
    end

    def default_performance_metrics
      { avg_viewers_current: 0, avg_viewers_previous: 0, peak_viewers_current: 0,
        peak_viewers_previous: 0, best_stream_day: 'N/A', best_stream_time: 'N/A',
        viewer_retention_score: 0 }
    end
  end
end
