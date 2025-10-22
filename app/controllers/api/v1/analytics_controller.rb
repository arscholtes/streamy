# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < BaseController
      before_action :set_user
      before_action :set_period, only: [:overview, :growth, :insights, :content, :compare]

      # GET /api/v1/users/:user_id/analytics/overview
      def overview
        metrics = calculate_metrics

        render json: {
          user_id: @user.id,
          period: {
            start: @period_start,
            end: @period_end
          },
          summary: {
            total_hours_streamed: metrics[:consistency][:total_hours_streamed],
            days_streamed: metrics[:consistency][:days_streamed],
            avg_viewers: metrics[:performance][:avg_viewers_current],
            peak_viewers: metrics[:performance][:peak_viewers_current],
            followers_gained: metrics[:growth][:total_followers_gained],
            engagement_score: metrics[:engagement][:engagement_score]
          },
          metrics: metrics
        }
      end

      # GET /api/v1/users/:user_id/analytics/growth
      def growth
        metrics = calculate_metrics
        growth_data = metrics[:growth]

        # Get historical data for chart
        summaries = @user.daily_stream_summaries
                         .for_date_range(@period_start, @period_end)
                         .chronological

        chart_data = summaries.map do |summary|
          {
            date: summary.summary_date,
            followers: summary.follower_count,
            avg_viewers: summary.avg_viewers,
            peak_viewers: summary.peak_viewers
          }
        end

        render json: {
          user_id: @user.id,
          growth: growth_data,
          trends: {
            follower_trend: growth_data[:avg_viewers_trend],
            viewer_trend: growth_data[:peak_viewers_trend]
          },
          chart_data: chart_data
        }
      end

      # GET /api/v1/users/:user_id/analytics/insights
      def insights
        metrics = calculate_metrics
        insights = generate_insights(metrics)
        context = build_context(metrics, insights)

        render json: {
          user_id: @user.id,
          insights: context[:insights_with_context],
          journey: context[:journey_summary],
          current_chapter: context[:current_chapter],
          milestones: context[:milestones],
          predictions: context[:predictions]
        }
      end

      # GET /api/v1/users/:user_id/analytics/content
      def content
        metrics = calculate_metrics
        content_data = metrics[:content]

        # Get detailed game performance
        game_sessions = @user.game_sessions
                             .where(started_at: @period_start.beginning_of_day..@period_end.end_of_day)

        games_performance = calculate_game_performance(game_sessions)

        render json: {
          user_id: @user.id,
          content: content_data,
          games: games_performance,
          recommendations: generate_content_recommendations(content_data, games_performance)
        }
      end

      # GET /api/v1/users/:user_id/analytics/audience
      def audience
        metrics = calculate_metrics
        engagement = metrics[:engagement]
        performance = metrics[:performance]

        # Get chat activity patterns
        snapshots = @user.stream_metric_snapshots
                         .between(@period_start.beginning_of_day, @period_end.end_of_day)

        chat_patterns = analyze_chat_patterns(snapshots)

        render json: {
          user_id: @user.id,
          engagement: engagement,
          retention: {
            score: performance[:viewer_retention_score],
            description: retention_description(performance[:viewer_retention_score])
          },
          chat_patterns: chat_patterns,
          best_times: {
            day: performance[:best_stream_day],
            time: performance[:best_stream_time]
          }
        }
      end

      # GET /api/v1/users/:user_id/analytics/compare
      def compare
        # Compare current period with previous period
        current_metrics = calculate_metrics

        # Calculate previous period
        period_length = (@period_end - @period_start).to_i + 1
        previous_start = @period_start - period_length.days
        previous_end = @period_start - 1.day

        previous_metrics = Analytics::MetricsCalculator.new(
          @user,
          period_start: previous_start,
          period_end: previous_end
        ).calculate_all

        comparison = build_comparison(current_metrics, previous_metrics)

        render json: {
          user_id: @user.id,
          current_period: {
            start: @period_start,
            end: @period_end
          },
          previous_period: {
            start: previous_start,
            end: previous_end
          },
          comparison: comparison
        }
      end

      # POST /api/v1/analytics/events
      def create_event
        user = User.find(params[:user_id])
        stream = params[:stream_id] ? Stream.find(params[:stream_id]) : nil

        AnalyticsEvent.create!(
          user: user,
          stream: stream,
          event_type: params[:event_type],
          event_data: params[:event_data] || {},
          occurred_at: params[:occurred_at] || Time.current
        )

        render json: { success: true, message: 'Event recorded' }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def set_period
        @period_start = params[:period_start] ? Date.parse(params[:period_start]) : 30.days.ago.to_date
        @period_end = params[:period_end] ? Date.parse(params[:period_end]) : Date.today
      rescue ArgumentError
        render json: { error: 'Invalid date format' }, status: :bad_request
      end

      def calculate_metrics
        @metrics ||= Analytics::MetricsCalculator.new(@user, period_start: @period_start, period_end: @period_end).calculate_all
      end

      def generate_insights(metrics)
        Analytics::InsightsGenerator.new(@user, metrics).generate_all
      end

      def build_context(metrics, insights)
        Analytics::ContextBuilder.new(@user, metrics, insights).build_context
      end

      def calculate_game_performance(game_sessions)
        game_sessions.group_by(&:game_name).map do |game_name, sessions|
          total_duration = sessions.sum { |s| s.duration || 0 }

          {
            name: game_name,
            platform: sessions.first.platform,
            sessions_count: sessions.count,
            total_hours: (total_duration / 3600.0).round(2),
            avg_duration_hours: sessions.count.zero? ? 0 : (total_duration / sessions.count.to_f / 3600.0).round(2),
            last_played: sessions.map(&:started_at).max
          }
        end.sort_by { |g| -g[:total_hours] }
      end

      def generate_content_recommendations(content_data, games_performance)
        recommendations = []

        if games_performance.size == 1
          recommendations << "Consider trying 1-2 additional games to attract more viewers"
        elsif games_performance.size > 5
          recommendations << "Focus on your top 3 performing games for consistency"
        end

        top_game = games_performance.first
        if top_game
          recommendations << "#{top_game[:name]} is your most-played game - analyze if it performs well viewer-wise"
        end

        recommendations
      end

      def analyze_chat_patterns(snapshots)
        return {} if snapshots.empty?

        hourly_chat = snapshots.group_by { |s| s.snapshot_at.hour }
                               .transform_values { |snaps| snaps.sum(&:chat_messages_count) / snaps.size.to_f }

        {
          most_active_hour: hourly_chat.max_by { |_, count| count }&.first,
          least_active_hour: hourly_chat.min_by { |_, count| count }&.first,
          avg_messages_per_minute: (snapshots.average(:chat_rate)&.round(2) || 0)
        }
      end

      def retention_description(score)
        case score
        when 0..30
          "Low retention - viewers are leaving early"
        when 31..50
          "Moderate retention - room for improvement"
        when 51..70
          "Good retention - most viewers stay engaged"
        when 71..100
          "Excellent retention - viewers love your content"
        else
          "No data yet"
        end
      end

      def build_comparison(current, previous)
        {
          growth: compare_metrics(current[:growth], previous[:growth]),
          engagement: compare_metrics(current[:engagement], previous[:engagement]),
          consistency: compare_metrics(current[:consistency], previous[:consistency]),
          performance: compare_metrics(current[:performance], previous[:performance])
        }
      end

      def compare_metrics(current, previous)
        comparison = {}

        current.each do |key, current_value|
          next unless current_value.is_a?(Numeric)

          previous_value = previous[key].to_f

          if previous_value.zero?
            change_pct = current_value.positive? ? 100.0 : 0.0
          else
            change_pct = ((current_value - previous_value) / previous_value * 100).round(2)
          end

          comparison[key] = {
            current: current_value,
            previous: previous_value,
            change: current_value - previous_value,
            change_percentage: change_pct,
            trend: change_pct > 5 ? 'up' : (change_pct < -5 ? 'down' : 'stable')
          }
        end

        comparison
      end
    end
  end
end