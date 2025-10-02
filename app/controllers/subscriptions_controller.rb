class SubscriptionsController < ApplicationController
  before_action :require_login

  # GET /subscriptions/new
  def new
    @plans = Subscription::PLANS
    @current_subscription = current_user.active_subscription
  end

  # POST /subscriptions
  def create
    plan = params[:plan]

    unless Subscription::PLANS.key?(plan) && plan != 'free'
      flash[:error] = "Invalid subscription plan"
      redirect_to new_subscription_path and return
    end

    # Check if user already has active subscription
    if current_user.active_subscription
      flash[:error] = "You already have an active subscription"
      redirect_to subscription_path and return
    end

    service = SubscriptionService.new(current_user)

    begin
      session = service.create_checkout_session(
        plan: plan,
        success_url: subscription_success_url,
        cancel_url: new_subscription_url
      )

      redirect_to session.url, allow_other_host: true
    rescue => e
      Rails.logger.error("Subscription creation error: #{e.message}")
      flash[:error] = "Failed to create checkout session. Please try again."
      redirect_to new_subscription_path
    end
  end

  # GET /subscription
  def show
    @subscription = current_user.active_subscription || current_user.subscriptions.last

    unless @subscription
      flash[:notice] = "You don't have any subscriptions yet"
      redirect_to new_subscription_path and return
    end

    @payments = current_user.payments.subscriptions.recent.limit(10)
  end

  # GET /subscriptions/success
  def success
    flash[:success] = "Successfully subscribed! Thank you for your support."
    redirect_to subscription_path
  end

  # DELETE /subscription/cancel
  def cancel
    service = SubscriptionService.new(current_user)

    if service.cancel_subscription
      flash[:success] = "Your subscription will be canceled at the end of the current billing period"
    else
      flash[:error] = "Failed to cancel subscription"
    end

    redirect_to subscription_path
  end

  # POST /subscription/reactivate
  def reactivate
    service = SubscriptionService.new(current_user)

    if service.reactivate_subscription
      flash[:success] = "Your subscription has been reactivated"
    else
      flash[:error] = "Failed to reactivate subscription"
    end

    redirect_to subscription_path
  end

  # POST /subscription/change_plan
  def change_plan
    new_plan = params[:plan]

    unless Subscription::PLANS.key?(new_plan) && new_plan != 'free'
      flash[:error] = "Invalid plan"
      redirect_to subscription_path and return
    end

    service = SubscriptionService.new(current_user)

    if service.change_plan(new_plan)
      flash[:success] = "Your plan has been changed to #{new_plan.titleize}"
    else
      flash[:error] = "Failed to change plan"
    end

    redirect_to subscription_path
  end

  # GET /subscription/portal
  def portal
    service = SubscriptionService.new(current_user)

    portal_session = service.create_portal_session(
      return_url: subscription_url
    )

    if portal_session
      redirect_to portal_session.url, allow_other_host: true
    else
      flash[:error] = "Failed to create portal session"
      redirect_to subscription_path
    end
  end
end
