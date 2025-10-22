# app/services/revenue_analytics_service.rb
# Service for aggregating and analyzing revenue data for streamers
class RevenueAnalyticsService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Total revenue across all time (in cents)
  def total_revenue
    succeeded_payments.sum(:amount_cents)
  end

  # Total revenue in dollars
  def total_revenue_dollars
    total_revenue / 100.0
  end

  # Revenue for current month (in cents)
  def current_month_revenue
    succeeded_payments
      .where('created_at >= ?', Time.current.beginning_of_month)
      .sum(:amount_cents)
  end

  # Revenue for current month in dollars
  def current_month_revenue_dollars
    current_month_revenue / 100.0
  end

  # Revenue breakdown by type
  def revenue_by_type
    succeeded_payments
      .group(:payment_type)
      .sum(:amount_cents)
      .transform_keys { |k| k.titleize }
      .transform_values { |v| v / 100.0 }
  end

  # Monthly revenue for the last N months (for charts)
  def monthly_chart_data(months = 12)
    start_date = months.months.ago.beginning_of_month

    # Group payments by month manually
    payments_by_month = succeeded_payments
      .where('created_at >= ?', start_date)
      .group_by { |p| p.created_at.beginning_of_month }

    # Build the data hash
    data = {}
    (0...months).reverse_each do |i|
      month = i.months.ago.beginning_of_month
      month_key = month.strftime("%b %Y")

      # Sum payments for this month
      month_payments = payments_by_month[month] || []
      data[month_key] = month_payments.sum(&:amount_cents) / 100.0
    end

    data
  end

  # Top supporters by total donation amount
  def top_supporters(limit = 10)
    succeeded_payments
      .where.not(user_id: nil)
      .group(:user_id)
      .select('user_id, SUM(amount_cents) as total_amount, COUNT(*) as payment_count')
      .order('total_amount DESC')
      .limit(limit)
      .map do |payment|
        {
          user: User.find(payment.user_id),
          total_amount: payment.total_amount / 100.0,
          payment_count: payment.payment_count
        }
      end
  end

  # Revenue statistics for a specific period
  def revenue_for_period(start_date, end_date)
    succeeded_payments
      .where(created_at: start_date..end_date)
      .sum(:amount_cents)
  end

  # Average transaction value
  def average_transaction_value
    total = succeeded_payments.sum(:amount_cents)
    count = succeeded_payments.count
    count > 0 ? (total / count.to_f / 100.0) : 0.0
  end

  # Revenue growth rate (month over month)
  def monthly_growth_rate
    current_month = current_month_revenue
    last_month = revenue_for_period(
      1.month.ago.beginning_of_month,
      1.month.ago.end_of_month
    )

    return 0.0 if last_month.zero?
    ((current_month - last_month) / last_month.to_f * 100).round(2)
  end

  # Export to CSV
  def to_csv
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << ['Date', 'Type', 'Amount (USD)', 'Status', 'From User', 'Description']

      succeeded_payments.order(created_at: :desc).each do |payment|
        csv << [
          payment.created_at.strftime('%Y-%m-%d %H:%M'),
          payment.payment_type.titleize,
          '$%.2f' % (payment.amount_cents / 100.0),
          payment.status.titleize,
          payment.user&.username || 'Anonymous',
          payment.description || '-'
        ]
      end
    end
  end

  # Monthly recurring revenue (MRR) from subscriptions
  def monthly_recurring_revenue
    # Subscriptions in the last 30 days
    subscription_revenue = succeeded_payments
      .where(payment_type: 'subscription')
      .where('created_at >= ?', 30.days.ago)
      .sum(:amount_cents)

    subscription_revenue / 100.0
  end

  # Revenue by game (if game sessions are tracked)
  def revenue_by_game
    # This requires joining with game_sessions
    # We'll calculate revenue during time periods when specific games were being played
    game_revenues = {}

    user.game_sessions.ended.each do |session|
      game_revenues[session.game_name] ||= 0

      # Find payments during this game session
      session_revenue = succeeded_payments
        .where('created_at BETWEEN ? AND ?', session.started_at, session.ended_at)
        .sum(:amount_cents)

      game_revenues[session.game_name] += session_revenue
    end

    game_revenues.transform_values { |v| v / 100.0 }
  end

  private

  def succeeded_payments
    # Get all payments where user is the recipient (streamer receiving money)
    user.received_payments.where(status: 'succeeded')
  end
end
