# app/controllers/application_controller.rb
# ApplicationController is the base controller that all other controllers inherit from
# Any methods or concerns added here are available in all controllers
# Learn more: https://guides.rubyonrails.org/action_controller_overview.html

class ApplicationController < ActionController::Base
  # Include the Authentication concern
  # This makes all authentication helper methods available in all controllers
  # Methods: current_user, logged_in?, require_login, log_in, log_out, redirect_if_logged_in
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # This prevents errors on older browsers that don't support modern features
  allow_browser versions: :modern
end
