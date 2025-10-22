class DailyStreamSummary < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :summary_date, presence: true, uniqueness: { scope: :user_id }
  validates :total_stream_time_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :stream_count, numericality: { greater_than_or_equal_to: 0 }
  validates :peak_viewers, numericality: { greater_than_or_equal_to: 0 }
  validates :avg_viewers, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_date, ->(date) { where(summary_date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(summary_date: start_date..end_date) }
  scope :recent, ->(limit = 30) { order(summary_date: :desc).limit(limit) }
  scope :chronological, -> { order(summary_date: :asc) }
  scope :this_week, -> { where(summary_date: 1.week.ago.to_date..Date.today) }
  scope :this_month, -> { where(summary_date: 1.month.ago.to_date..Date.today) }
  scope :last_30_days, -> { where(summary_date: 30.days.ago.to_date..Date.today) }

  # Class methods
  def self.aggregate_for_period(user_id, start_date, end_date)
    summaries = for_user(user_id).for_date_range(start_date, end_date)

    {
      total_stream_time_seconds: summaries.sum(:total_stream_time_seconds),
      total_streams: summaries.sum(:stream_count),
      avg_viewers: (summaries.average(:avg_viewers)&.round || 0),
      peak_viewers: summaries.maximum(:peak_viewers) || 0,
      total_chat_messages: summaries.sum(:total_chat_messages),
      total_followers_gained: summaries.sum(:followers_gained),
      total_revenue: summaries.sum(:revenue_earned),
      days_streamed: summaries.where('stream_count > 0').count
    }
  end

  def self.compare_periods(user_id, current_start, current_end, previous_start, previous_end)
    current = aggregate_for_period(user_id, current_start, current_end)
    previous = aggregate_for_period(user_id, previous_start, previous_end)

    {
      current: current,
      previous: previous,
      changes: calculate_changes(current, previous)
    }
  end

  def self.calculate_changes(current, previous)
    changes = {}

    current.each do |key, current_value|
      previous_value = previous[key] || 0

      if previous_value.zero?
        change_pct = current_value.positive? ? 100.0 : 0.0
      else
        change_pct = ((current_value - previous_value) / previous_value.to_f * 100).round(2)
      end

      changes[key] = {
        value: current_value - previous_value,
        percentage: change_pct
      }
    end

    changes
  end

  # Instance methods
  def total_stream_time_hours
    (total_stream_time_seconds / 3600.0).round(2)
  end

  def avg_stream_duration_hours
    return 0 if stream_count.zero?

    (total_stream_time_seconds / stream_count.to_f / 3600.0).round(2)
  end

  def engagement_rate
    return 0 if avg_viewers.zero?

    (unique_chatters / avg_viewers.to_f * 100).round(2)
  end

  def follower_retention_rate
    return 100.0 if followers_lost.zero?

    gained = followers_gained.zero? ? 1 : followers_gained
    ((gained - followers_lost) / gained.to_f * 100).round(2)
  end

  def streamed_today?
    stream_count.positive?
  end
end
