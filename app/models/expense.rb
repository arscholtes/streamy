class Expense < ApplicationRecord
  belongs_to :user

  # Expense categories for tax purposes
  CATEGORIES = %w[
    equipment
    software
    marketing
    internet
    utilities
    office_supplies
    professional_services
    travel
    meals
    entertainment
    education
    other
  ].freeze

  # Validations
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :date, presence: true
  validates :tax_deductible, inclusion: { in: [true, false] }

  # Scopes
  scope :tax_deductible, -> { where(tax_deductible: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :for_year, ->(year) { where('EXTRACT(YEAR FROM date) = ?', year) }
  scope :for_month, ->(year, month) { where('EXTRACT(YEAR FROM date) = ? AND EXTRACT(MONTH FROM date) = ?', year, month) }
  scope :recent, -> { order(date: :desc) }
  scope :this_year, -> { where('date >= ?', Date.today.beginning_of_year) }
  scope :this_month, -> { where('date >= ?', Date.today.beginning_of_month) }

  # Instance methods
  def amount_dollars
    amount_cents / 100.0
  end

  def amount_dollars=(dollars)
    self.amount_cents = (dollars.to_f * 100).to_i
  end

  def category_label
    category.titleize
  end

  # Class methods
  def self.total_for_period(start_date, end_date)
    where(date: start_date..end_date).sum(:amount_cents)
  end

  def self.by_category_summary
    group(:category).sum(:amount_cents).transform_values { |v| v / 100.0 }
  end

  def self.tax_deductible_total(year = Date.today.year)
    tax_deductible.for_year(year).sum(:amount_cents) / 100.0
  end

  # Export to CSV
  def self.to_csv(expenses)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << ['Date', 'Category', 'Amount (USD)', 'Tax Deductible', 'Description', 'Receipt']

      expenses.each do |expense|
        csv << [
          expense.date.strftime('%Y-%m-%d'),
          expense.category_label,
          '$%.2f' % expense.amount_dollars,
          expense.tax_deductible? ? 'Yes' : 'No',
          expense.description || '-',
          expense.receipt_url || '-'
        ]
      end
    end
  end
end
