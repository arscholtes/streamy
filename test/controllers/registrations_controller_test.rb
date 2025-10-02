# test/controllers/registrations_controller_test.rb
# This file tests the RegistrationsController which handles user signup
# Learn more about controller testing: https://guides.rubyonrails.org/testing.html#functional-tests-for-your-controllers

require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  # TEST: new action (signup page)
  # This displays the signup form
  test "should get new" do
    # GET request to the signup page
    get signup_path

    # assert_response checks the HTTP status code
    # :success means 200 OK
    assert_response :success

    # Check that the page title contains "Sign Up"
    assert_select "title", /Sign Up/
  end

  # TEST: create action with valid data
  # This creates a new user successfully
  test "should create user with valid data" do
    # assert_difference checks that the block changes a value
    # In this case, we expect User.count to increase by 1
    # Learn more: https://api.rubyonrails.org/classes/ActiveSupport/Testing/Assertions.html#method-i-assert_difference
    assert_difference "User.count", 1 do
      # POST request to registrations#create with valid user data
      post registration_path, params: {
        user: {
          username: "newuser",                      # Valid username
          email: "newuser@example.com",             # Valid email
          password: "password123",                  # Valid password
          password_confirmation: "password123"      # Matches password
        }
      }
    end

    # After successful signup, user should be logged in automatically
    # session[:user_id] should be set to the new user's ID
    assert_not_nil session[:user_id]

    # Should redirect to root page (dashboard)
    assert_redirected_to root_path

    # Follow the redirect and check for success message
    follow_redirect!
    assert_select "div.alert-success", /Welcome/i
  end

  # TEST: create action should auto-login user after signup
  test "should automatically login user after successful signup" do
    post registration_path, params: {
      user: {
        username: "autouser",
        email: "auto@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    # Verify user is logged in by checking session
    user = User.find_by(username: "autouser")
    assert_equal user.id, session[:user_id]
  end

  # TEST: create action with invalid data (missing username)
  # Should not create user and should show errors
  test "should not create user without username" do
    # assert_no_difference ensures User.count doesn't change
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          username: "",                             # Blank username (invalid)
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    # Should re-render the signup form (not redirect)
    assert_response :success
    # Should display the form with errors
    assert_select "form"
  end

  # TEST: create action with invalid data (missing email)
  test "should not create user without email" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          username: "testuser",
          email: "",                                # Blank email (invalid)
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :success
  end

  # TEST: create action with invalid data (short password)
  test "should not create user with short password" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          username: "testuser",
          email: "test@example.com",
          password: "12345",                        # Only 5 characters (too short)
          password_confirmation: "12345"
        }
      }
    end

    assert_response :success
  end

  # TEST: create action with mismatched password confirmation
  test "should not create user when password confirmation doesn't match" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          username: "testuser",
          email: "test@example.com",
          password: "password123",
          password_confirmation: "different123"    # Doesn't match password
        }
      }
    end

    assert_response :success
  end

  # TEST: create action with duplicate username
  # Should handle uniqueness validation
  test "should not create user with duplicate username" do
    # Create a user first
    User.create!(
      username: "existinguser",
      email: "existing@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Try to create another user with the same username
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          username: "existinguser",               # Duplicate username
          email: "different@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :success
    # Check for error message about username being taken
    assert_select "form"
  end

  # TEST: create action with duplicate email
  test "should not create user with duplicate email" do
    # Create a user first
    User.create!(
      username: "existinguser",
      email: "existing@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Try to create another user with the same email
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          username: "differentuser",
          email: "existing@example.com",          # Duplicate email
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :success
  end

  # TEST: create action with invalid email format
  test "should not create user with invalid email format" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          username: "testuser",
          email: "invalid-email",                 # Invalid email format
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :success
  end

  # TEST: should redirect to login if already logged in
  # Logged-in users shouldn't access the signup page
  test "should redirect logged in user from signup page" do
    # Create and login a user
    user = User.create!(
      username: "loggedinuser",
      email: "loggedin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Simulate being logged in by setting session
    post session_path, params: {
      session: {
        username: user.username,
        password: "password123"
      }
    }

    # Try to access signup page while logged in
    get signup_path

    # Should redirect to root page (already logged in)
    assert_redirected_to root_path
  end
end
