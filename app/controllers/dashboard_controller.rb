# app/controllers/dashboard_controller.rb
# DashboardController shows the main user dashboard after login
# This is the landing page for authenticated users
# Learn more: https://guides.rubyonrails.org/action_controller_overview.html

class DashboardController < ApplicationController
  # Require user to be logged in to access dashboard
  # require_login is from the Authentication concern
  before_action :require_login

  # index action displays the dashboard
  # GET /dashboard
  def index
    # Get the current user's streams
    # @streams will be available in the view
    # Learn more about instance variables in views: https://guides.rubyonrails.org/action_view_overview.html
    @streams = current_user.streams

    # Get the user's primary stream (first one, or create if none exist)
    # Most users will have one main stream they broadcast to
    @stream = @streams.first || current_user.streams.create!(
      title: "#{current_user.username}'s Stream",
      status: "offline"
    )

    # Calculate streaming statistics
    # These will be displayed in dashboard cards
    @total_streams = @streams.count
    @active_streams = @streams.where(status: "live").count

    # Get subscription tier info for billing section
    @subscription = current_user.subscription_tier

    # This renders app/views/dashboard/index.html.erb
  end
end
