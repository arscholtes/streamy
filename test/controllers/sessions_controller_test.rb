# test/controllers/sessions_controller_test.rb
# This file tests the SessionsController which handles user login/logout
# Learn more about controller testing: https://guides.rubyonrails.org/testing.html#functional-tests-for-your-controllers

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  # Setup runs before each test
  def setup
    # Create a test user to use for authentication tests
    # We use create! (with !) so it raises an error if creation fails
    @user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # TEST: new action (login page)
  # This displays the login form
  test "should get new" do
    # GET request to the login page
    # new_session_path will be defined in routes.rb
    get new_session_path

    # assert_response checks the HTTP status code
    # :success means 200 OK
    assert_response :success

    # Check that the page title contains "Login"
    assert_select "title", /Login/
  end

  # TEST: create action with valid credentials
  # This logs the user in successfully
  test "should login with valid credentials" do
    # POST request to sessions#create with username and password
    # This simulates submitting the login form
    post session_path, params: {
      session: {
        username: @user.username,  # Use the username from our test user
        password: "password123"    # Correct password
      }
    }

    # assert_redirected_to checks if user was redirected to the right page
    # After successful login, redirect to root page (will be dashboard later)
    assert_redirected_to root_path

    # Check that the user_id was stored in the session
    # Rails session is a hash-like object that stores data across requests
    # Learn more: https://guides.rubyonrails.org/action_controller_overview.html#session
    assert_equal @user.id, session[:user_id]

    # Follow the redirect to check the flash message
    follow_redirect!

    # assert_select checks the HTML response for specific content
    # Check that a success flash message is displayed
    assert_select "div.alert-success", /logged in/i
  end

  # TEST: create action with email instead of username
  # Users should be able to login with email OR username
  test "should login with email" do
    post session_path, params: {
      session: {
        username: @user.email,     # Use email in the username field
        password: "password123"
      }
    }

    assert_redirected_to root_path
    assert_equal @user.id, session[:user_id]
  end

  # TEST: create action with invalid password
  # Should not login and should show error message
  test "should not login with invalid password" do
    post session_path, params: {
      session: {
        username: @user.username,
        password: "wrongpassword"  # Incorrect password
      }
    }

    # Should not redirect (stays on login page)
    assert_response :success

    # Session should be empty (not logged in)
    assert_nil session[:user_id]

    # Check for error flash message
    # flash.now is used for messages that should only appear on the current page
    assert_select "div.alert-danger", /Invalid/i
  end

  # TEST: create action with non-existent username
  # Should handle users that don't exist
  test "should not login with non-existent username" do
    post session_path, params: {
      session: {
        username: "nonexistent",   # User doesn't exist
        password: "password123"
      }
    }

    assert_response :success
    assert_nil session[:user_id]
    assert_select "div.alert-danger", /Invalid/i
  end

  # TEST: create action with blank credentials
  # Should handle empty form submission
  test "should not login with blank credentials" do
    post session_path, params: {
      session: {
        username: "",  # Blank username
        password: ""   # Blank password
      }
    }

    assert_response :success
    assert_nil session[:user_id]
    assert_select "div.alert-danger", /Invalid/i
  end

  # TEST: destroy action (logout)
  # Should log the user out and clear session
  test "should logout" do
    # First, login the user by setting session[:user_id]
    # This simulates a logged-in state
    # Learn more about test sessions: https://guides.rubyonrails.org/testing.html#the-three-environments
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Verify user is logged in
    assert_equal @user.id, session[:user_id]

    # DELETE request to sessions#destroy to logout
    # RESTful convention: DELETE is used to destroy a resource (the session)
    delete session_path(@user)

    # Should redirect to login page after logout
    assert_redirected_to login_path

    # Session should be cleared (no user_id)
    assert_nil session[:user_id]

    # Check for logout success message
    follow_redirect!
    assert_select "div.alert-success", /logged out/i
  end

  # TEST: should not be able to access protected pages when logged out
  # This will be useful when we add authentication requirements later
  test "should redirect to login when accessing protected pages while logged out" do
    # This test prepares for future functionality
    # For now, it's a placeholder that passes
    assert true
  end
end
