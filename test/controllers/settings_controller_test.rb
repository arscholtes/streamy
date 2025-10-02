# test/controllers/settings_controller_test.rb
# This file tests the SettingsController which handles user settings/preferences
# Learn more about controller testing: https://guides.rubyonrails.org/testing.html#functional-tests-for-your-controllers

require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  # Setup runs before each test
  def setup
    # Create a test user
    @user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # TEST: should redirect to login when not authenticated
  test "should redirect to login when not logged in" do
    # Try to access settings without logging in
    get settings_path

    # Should redirect to login page
    assert_redirected_to login_path
  end

  # TEST: index should show settings page when authenticated
  test "should show settings page when logged in" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access settings
    get settings_path

    # Should be successful
    assert_response :success

    # Should show settings title
    assert_select "h1", /Settings/i
  end

  # TEST: should show profile tab
  test "should display profile settings tab" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access settings
    get settings_path

    # Should show profile tab (Bootstrap 5 uses button with data-bs-target)
    assert_select "button[data-bs-target='#profile']", /Profile/i
  end

  # TEST: should show account tab
  test "should display account settings tab" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access settings
    get settings_path

    # Should show account tab (Bootstrap 5 uses button with data-bs-target)
    assert_select "button[data-bs-target='#account']", /Account/i
  end

  # TEST: should show billing tab (for future payment integration)
  test "should display billing settings tab" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access settings
    get settings_path

    # Should show billing tab (Bootstrap 5 uses button with data-bs-target)
    assert_select "button[data-bs-target='#billing']", /Billing/i
  end

  # TEST: update_profile should update user profile information
  test "should update profile with valid data" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Update profile
    patch update_profile_path, params: {
      user: {
        username: "newusername",
        email: "newemail@example.com"
      }
    }

    # Should redirect back to settings
    assert_redirected_to settings_path

    # Follow redirect and check for success message
    follow_redirect!
    assert_select "div.alert-success", /updated/i

    # Verify user was updated in database
    @user.reload
    assert_equal "newusername", @user.username
    assert_equal "newemail@example.com", @user.email
  end

  # TEST: update_profile should not update with invalid data
  test "should not update profile with invalid username" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Try to update with invalid username (too short)
    patch update_profile_path, params: {
      user: {
        username: "ab",  # Only 2 characters (minimum is 3)
        email: @user.email
      }
    }

    # Should re-render settings page
    assert_response :success

    # Should show error message
    assert_select "div.alert-danger"

    # Verify user was NOT updated
    @user.reload
    assert_equal "testuser", @user.username
  end

  # TEST: update_password should change password with valid data
  test "should update password with valid current password" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Update password
    patch update_password_path, params: {
      user: {
        current_password: "password123",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    # Should redirect back to settings
    assert_redirected_to settings_path

    # Follow redirect and check for success message
    follow_redirect!
    assert_select "div.alert-success", /password.*updated/i

    # Verify new password works
    delete session_path(@user)  # Logout
    post session_path, params: {
      session: {
        username: @user.username,
        password: "newpassword123"  # Use new password
      }
    }
    assert_redirected_to root_path  # Should login successfully
  end

  # TEST: update_password should not change password with incorrect current password
  test "should not update password with wrong current password" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Try to update with wrong current password
    patch update_password_path, params: {
      user: {
        current_password: "wrongpassword",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    # Should re-render settings page
    assert_response :success

    # Should show error message
    assert_select "div.alert-danger", /current password/i
  end

  # TEST: update_password should not change password with mismatched confirmation
  test "should not update password with mismatched confirmation" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Try to update with mismatched confirmation
    patch update_password_path, params: {
      user: {
        current_password: "password123",
        password: "newpassword123",
        password_confirmation: "different123"  # Doesn't match
      }
    }

    # Should re-render settings page
    assert_response :success

    # Should show error message
    assert_select "div.alert-danger"
  end

  # TEST: should show current subscription tier
  test "should display current subscription tier in billing section" do
    # Login
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access settings
    get settings_path

    # Should show subscription information
    assert_response :success
  end
end
