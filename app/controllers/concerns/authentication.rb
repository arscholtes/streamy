# app/controllers/concerns/authentication.rb
# Authentication concern provides helper methods for user authentication
# Concerns are modules that can be included in controllers to share functionality
# Learn more: https://api.rubyonrails.org/classes/ActiveSupport/Concern.html
# Learn more about Rails concerns: https://guides.rubyonrails.org/action_controller_overview.html#filters

module Authentication
  # extend ActiveSupport::Concern allows us to use special concern syntax
  # It provides convenient ways to add class methods and instance methods
  extend ActiveSupport::Concern

  # included block runs when this concern is included in a controller
  # This is where we define helpers that should be available in views
  included do
    # helper_method makes controller methods available in views
    # Without this, only controllers can use these methods
    # Learn more: https://api.rubyonrails.org/classes/AbstractController/Helpers/ClassMethods.html#method-i-helper_method
    helper_method :current_user, :logged_in?
  end

  # INSTANCE METHODS
  # These methods are available in any controller that includes this concern

  # current_user returns the currently logged-in user (or nil if not logged in)
  # This method is memoized (cached) to avoid database queries on every call
  # Example usage in controller: current_user.username
  # Example usage in view: <%= current_user.email %>
  def current_user
    # ||= is the "or equals" operator (memoization pattern)
    # If @current_user is already set, return it
    # If @current_user is nil, execute the right side and store the result
    # This means we only query the database once per request
    # Learn more: https://www.justinweiss.com/articles/4-simple-memoization-patterns-in-ruby-and-one-gem/
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]

    # Explanation of the code above:
    # 1. if session[:user_id] - check if user_id exists in session
    # 2. User.find_by(id: session[:user_id]) - find user in database
    # 3. @current_user ||= ... - cache the result in @current_user
    # 4. Returns nil if session[:user_id] is nil or user not found
  end

  # logged_in? returns true if a user is logged in, false otherwise
  # This is a boolean helper method for checking authentication status
  # Example usage in controller: redirect_to login_path unless logged_in?
  # Example usage in view: <% if logged_in? %>...logged in content...<% end %>
  def logged_in?
    # !!current_user converts the user object to a boolean
    # !! is the double-bang operator (double negation)
    # First ! converts truthy value to false, nil to true
    # Second ! converts it back: true if user exists, false if nil
    # Learn more: https://stackoverflow.com/questions/1489183/double-bang-in-ruby
    !!current_user

    # Alternative implementation (same result):
    # current_user.present?
    # or
    # !current_user.nil?
  end

  # require_login is a before_action filter that ensures user is logged in
  # Use this in controllers to protect actions that require authentication
  # Example: before_action :require_login, only: [:edit, :update, :destroy]
  # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#filters
  def require_login
    # Check if user is NOT logged in
    unless logged_in?
      # Set an error message
      flash[:danger] = "You must be logged in to access this page."

      # Redirect to login page
      redirect_to login_path

      # Return false to stop the filter chain
      # This prevents the action from executing
      # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#halting-the-filter-chain
    end
  end

  # log_in is a helper method to log in a user
  # This sets the session[:user_id] and caches the user
  # Example usage: log_in(@user)
  def log_in(user)
    # Set the user_id in the session (this logs them in)
    session[:user_id] = user.id

    # Cache the user object to avoid an extra database query
    @current_user = user
  end

  # log_out is a helper method to log out the current user
  # This clears the session and the cached user
  # Example usage: log_out
  def log_out
    # Clear the user_id from the session
    session.delete(:user_id)

    # Clear the cached current_user
    @current_user = nil
  end

  # redirect_if_logged_in redirects logged-in users away from public pages
  # Use this to prevent logged-in users from accessing login/signup pages
  # Example: before_action :redirect_if_logged_in, only: [:new, :create]
  def redirect_if_logged_in
    if logged_in?
      flash[:notice] = "You are already logged in."
      redirect_to root_path
    end
  end
end
