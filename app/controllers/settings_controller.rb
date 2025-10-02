# app/controllers/settings_controller.rb
# SettingsController handles user settings and preferences
# Includes profile, account, and billing settings (for future payment integration)
# Learn more: https://guides.rubyonrails.org/action_controller_overview.html

class SettingsController < ApplicationController
  # Require user to be logged in to access settings
  before_action :require_login

  # index action displays the settings page
  # GET /settings
  def index
    # @user will be available in the view for form binding
    @user = current_user

    # This renders app/views/settings/index.html.erb
  end

  # update_profile action updates user profile information
  # PATCH /settings/profile
  def update_profile
    # Get current user
    @user = current_user

    # user_profile_params filters allowed parameters (strong parameters)
    # This prevents users from modifying fields they shouldn't
    if @user.update(user_profile_params)
      # Update successful
      flash[:success] = "Your profile has been updated successfully!"
      redirect_to settings_path
    else
      # Update failed - validation errors
      flash.now[:danger] = "Unable to update profile. Please check the errors below."

      # Re-render settings page with errors
      render :index
    end
  end

  # update_password action changes user password
  # PATCH /settings/password
  def update_password
    # Get current user
    @user = current_user

    # Verify current password before allowing change
    # This is a security measure to prevent unauthorized password changes
    # Learn more: https://guides.rubyonrails.org/security.html
    if @user.authenticate(password_params[:current_password])
      # Current password is correct, proceed with update

      # Update password with new values
      if @user.update(password: password_params[:password],
                      password_confirmation: password_params[:password_confirmation])
        # Password updated successfully
        flash[:success] = "Your password has been updated successfully!"
        redirect_to settings_path
      else
        # New password validation failed (too short, doesn't match, etc.)
        flash.now[:danger] = "Unable to update password. Please check the errors below."
        render :index
      end
    else
      # Current password is incorrect
      flash.now[:danger] = "Current password is incorrect. Please try again."
      render :index
    end
  end

  private

  # Strong parameters for profile update
  # Only allow username and email to be updated
  # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters
  def user_profile_params
    params.require(:user).permit(:username, :email)
  end

  # Strong parameters for password update
  # Require current password for security
  # Allow new password and confirmation
  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
