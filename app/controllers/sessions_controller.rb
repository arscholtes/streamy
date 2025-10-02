# app/controllers/sessions_controller.rb
# SessionsController handles user authentication (login/logout)
# Learn more about controllers: https://guides.rubyonrails.org/action_controller_overview.html

class SessionsController < ApplicationController
  # new action displays the login form
  # GET /login
  def new
    # This renders app/views/sessions/new.html.erb
    # render is implicit - Rails automatically renders a view matching the action name
  end

  # create action processes the login form submission
  # POST /login
  def create
    # Extract the username/email and password from params
    # params is a hash containing all form data and URL parameters
    # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#parameters
    username_or_email = params[:session][:username]
    password = params[:session][:password]

    # Find user by username OR email
    # We use downcase to make the search case-insensitive
    # find_by returns nil if no user is found (doesn't raise an error)
    user = User.find_by(username: username_or_email.downcase) ||
           User.find_by(email: username_or_email.downcase)

    # Authenticate the user
    # && is the "and" operator - both conditions must be true
    # user.authenticate(password) comes from has_secure_password
    # It returns the user object if password is correct, false otherwise
    if user && user.authenticate(password)
      # Login successful!

      # Use the log_in helper method from Authentication concern
      # This sets session[:user_id] and caches the user
      log_in(user)

      # flash is used to display messages to the user
      # flash[:success] will be displayed as a success message (green)
      # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#the-flash
      flash[:success] = "You have been successfully logged in!"

      # redirect_to sends the user to a different page
      # root_path is the root URL of the application (/)
      # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#redirecting
      redirect_to root_path
    else
      # Login failed - invalid username/email or password

      # flash.now is used for messages that should only appear on the current page
      # Regular flash would persist to the next page, but we're rendering (not redirecting)
      flash.now[:danger] = "Invalid username/email or password"

      # render :new displays the login form again with error message
      # We use render instead of redirect so the form data is preserved
      render :new
    end
  end

  # destroy action logs the user out
  # DELETE /logout
  def destroy
    # Use the log_out helper method from Authentication concern
    # This clears session[:user_id] and @current_user
    log_out

    # Set a success message
    flash[:success] = "You have been logged out successfully!"

    # Redirect to the login page
    redirect_to login_path
  end
end
