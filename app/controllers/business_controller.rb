# app/controllers/business_controller.rb
# BusinessController handles the business dashboard for streamers
# Provides revenue analytics, expense tracking, and financial reports
class BusinessController < ApplicationController
  before_action :require_login

  def index
    # Load revenue analytics service
    @revenue_service = RevenueAnalyticsService.new(current_user)

    # Revenue metrics
    @total_revenue = @revenue_service.total_revenue
    @monthly_revenue = @revenue_service.current_month_revenue
    @revenue_by_type = @revenue_service.revenue_by_type
    @monthly_chart_data = @revenue_service.monthly_chart_data(12) # Last 12 months
    @top_supporters = @revenue_service.top_supporters(10)

    # Expense metrics (use 'date' field, not 'created_at')
    @total_expenses = current_user.expenses.sum(:amount_cents) rescue 0
    @monthly_expenses = current_user.expenses.where('date >= ?', Time.current.beginning_of_month).sum(:amount_cents) rescue 0

    # Profit calculations
    @total_profit = @total_revenue - @total_expenses
    @monthly_profit = @monthly_revenue - @monthly_expenses

    # Monthly expense chart data (for trends)
    @monthly_expense_data = monthly_expense_chart_data(current_user, 12)

    # Recent expenses
    @recent_expenses = current_user.expenses.order(date: :desc).limit(5) rescue []

    # Subscription metrics
    @active_subscriptions = current_user.received_payments
      .where(payment_type: 'subscription', status: 'succeeded')
      .where('created_at >= ?', 30.days.ago)
      .count

    @subscription_mrr = current_user.received_payments
      .where(payment_type: 'subscription', status: 'succeeded')
      .where('created_at >= ?', 30.days.ago)
      .sum(:amount_cents)
  end

  def export_revenue
    # Export revenue data to CSV
    @revenue_service = RevenueAnalyticsService.new(current_user)

    respond_to do |format|
      format.csv do
        send_data @revenue_service.to_csv,
          filename: "revenue_report_#{Date.today}.csv",
          type: 'text/csv',
          disposition: 'attachment'
      end
    end
  end

  private

  def monthly_expense_chart_data(user, months = 12)
    start_date = months.months.ago.beginning_of_month

    # Group expenses by month
    expenses_by_month = user.expenses
      .where('date >= ?', start_date)
      .group_by { |e| e.date.beginning_of_month }

    # Build the data hash
    data = {}
    (0...months).reverse_each do |i|
      month = i.months.ago.beginning_of_month
      month_key = month.strftime("%b %Y")

      # Sum expenses for this month
      month_expenses = expenses_by_month[month] || []
      data[month_key] = month_expenses.sum(&:amount_cents) / 100.0
    end

    data
  end
end
