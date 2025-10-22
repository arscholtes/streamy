class UserAnalyticsSummary < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :period_type, presence: true, inclusion: { in: %w[daily weekly monthly] }
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :period_start, uniqueness: { scope: [:user_id, :period_type] }
  validate :period_end_after_start

  # Scopes
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :by_period_type, ->(period_type) { where(period_type: period_type) }
  scope :daily, -> { where(period_type: 'daily') }
  scope :weekly, -> { where(period_type: 'weekly') }
  scope :monthly, -> { where(period_type: 'monthly') }
  scope :recent, ->(limit = 10) { order(period_start: :desc).limit(limit) }
  scope :chronological, -> { order(period_start: :asc) }
  scope :for_date_range, ->(start_date, end_date) { where('period_start >= ? AND period_end <= ?', start_date, end_date) }

  # Class methods
  def self.latest_for_user(user_id, period_type = 'weekly')
    for_user(user_id).by_period_type(period_type).order(period_start: :desc).first
  end

  def self.create_or_update_summary(user_id, period_type, period_start, period_end, metrics, insights = {})
    summary = find_or_initialize_by(
      user_id: user_id,
      period_type: period_type,
      period_start: period_start
    )

    summary.assign_attributes(
      period_end: period_end,
      metrics: metrics,
      insights: insights,
      metadata: {
        generated_at: Time.current,
        version: '1.0'
      }
    )

    summary.save!
    summary
  end

  # Instance methods
  def period_duration_days
    (period_end - period_start).to_i + 1
  end

  def metric(key)
    metrics[key.to_s]
  end

  def insight(key)
    insights[key.to_s]
  end

  def set_metric(key, value)
    self.metrics = metrics.merge(key.to_s => value)
  end

  def set_insight(key, value)
    self.insights = insights.merge(key.to_s => value)
  end

  def growth_percentage(metric_key)
    previous_summary = self.class
                           .for_user(user_id)
                           .by_period_type(period_type)
                           .where('period_start < ?', period_start)
                           .order(period_start: :desc)
                           .first

    return nil unless previous_summary

    current_value = metric(metric_key).to_f
    previous_value = previous_summary.metric(metric_key).to_f

    return 100.0 if previous_value.zero? && current_value.positive?
    return 0.0 if previous_value.zero?

    ((current_value - previous_value) / previous_value * 100).round(2)
  end

  def trend_direction(metric_key)
    growth = growth_percentage(metric_key)

    return 'stable' if growth.nil? || growth.abs < 5

    growth.positive? ? 'up' : 'down'
  end

  private

  def period_end_after_start
    if period_end.present? && period_start.present? && period_end < period_start
      errors.add(:period_end, "must be after or equal to period start")
    end
  end
end
