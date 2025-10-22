# app/controllers/expenses_controller.rb
# ExpensesController handles CRUD operations for business expenses
class ExpensesController < ApplicationController
  before_action :require_login
  before_action :set_expense, only: [:edit, :update, :destroy]

  def index
    @expenses = current_user.expenses.recent.page(params[:page]).per(20)

    @total_expenses = current_user.expenses.sum(:amount_cents) / 100.0
    @this_year_expenses = current_user.expenses.this_year.sum(:amount_cents) / 100.0
    @this_month_expenses = current_user.expenses.this_month.sum(:amount_cents) / 100.0
    @tax_deductible_total = current_user.expenses.tax_deductible_total(Date.today.year)

    @category_breakdown = current_user.expenses.by_category_summary

    respond_to do |format|
      format.html
      format.csv do
        send_data Expense.to_csv(current_user.expenses.recent),
          filename: "expenses_#{Date.today}.csv",
          type: 'text/csv',
          disposition: 'attachment'
      end
    end
  end

  def new
    @expense = current_user.expenses.new(date: Date.today)
  end

  def create
    @expense = current_user.expenses.new(expense_params)

    if @expense.save
      redirect_to expenses_path, notice: 'Expense added successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to expenses_path, notice: 'Expense updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to expenses_path, notice: 'Expense deleted successfully.'
  end

  private

  def set_expense
    @expense = current_user.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(
      :amount_cents,
      :category,
      :description,
      :receipt_url,
      :date,
      :tax_deductible
    )
  end
end