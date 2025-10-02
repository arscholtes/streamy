# app/controllers/registrations_controller.rb
# RegistrationsController handles user signup (registration)
# Learn more about controllers: https://guides.rubyonrails.org/action_controller_overview.html

class RegistrationsController < ApplicationController
  # before_action runs before specified actions
  # redirect_if_logged_in is from the Authentication concern
  # This checks if user is already logged in before showing signup page
  # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#filters
  before_action :redirect_if_logged_in, only: [ :new ]

  # new action displays the signup form
  # GET /signup
  def new
    # Create a new User object for the form
    # This is used by form_with to build the form fields
    @user = User.new
  end

  # create action processes the signup form submission
  # POST /signup
  def create
    # Build a new User object with parameters from the form
    # user_params is a private method that filters allowed parameters (strong parameters)
    # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters
    @user = User.new(user_params)

    # Try to save the user to the database
    # save returns true if successful, false if validations fail
    if @user.save
      # Signup successful!

      # Automatically log the user in using the log_in helper from Authentication concern
      # This is a common UX pattern - users shouldn't have to login after signup
      log_in(@user)

      # Set success message
      flash[:success] = "Welcome to StreamHub, #{@user.username}! Your account has been created successfully."

      # Redirect to root page (dashboard)
      redirect_to root_path
    else
      # Signup failed - validations didn't pass

      # render :new displays the signup form again with error messages
      # @user still contains the invalid data, so the form can show errors
      # Rails automatically adds error messages to @user.errors
      render :new
    end
  end

  private

  # Strong parameters - whitelist allowed parameters
  # This prevents mass assignment vulnerabilities
  # Only these specific fields can be set from the form
  # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters
  def user_params
    # params[:user] contains the form data
    # require(:user) ensures the :user key exists
    # permit(...) specifies which attributes are allowed
    params.require(:user).permit(
      :username,                # Allow username
      :email,                   # Allow email
      :password,                # Allow password
      :password_confirmation    # Allow password_confirmation
    )
  end

  # Note: redirect_if_logged_in is now provided by the Authentication concern
  # No need to define it here anymore - it's available through ApplicationController
end
