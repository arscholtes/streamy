# app/controllers/analytics_controller.rb
# Analytics dashboard for streamers
class AnalyticsController < ApplicationController
  before_action :require_login

  def index
    # Get analytics data from the service
    @period_start = params[:period_start] ? Date.parse(params[:period_start]) : 30.days.ago.to_date
    @period_end = params[:period_end] ? Date.parse(params[:period_end]) : Date.today

    # Use the analytics calculator service
    @calculator = Analytics::MetricsCalculator.new(
      current_user,
      period_start: @period_start,
      period_end: @period_end
    )

    @metrics = @calculator.calculate_all

    # Get daily summaries for charts
    @daily_summaries = current_user.daily_stream_summaries
                                   .for_date_range(@period_start, @period_end)
                                   .chronological

    # Recent streams
    @recent_streams = current_user.streams
                                  .where('created_at >= ?', @period_start)
                                  .order(created_at: :desc)
                                  .limit(10)
  end
end
