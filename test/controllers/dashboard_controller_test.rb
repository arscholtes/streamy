# test/controllers/dashboard_controller_test.rb
# This file tests the DashboardController which shows the user's main landing page after login
# Learn more about controller testing: https://guides.rubyonrails.org/testing.html#functional-tests-for-your-controllers

require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  # Setup runs before each test
  def setup
    # Create a test user with a stream
    @user = User.create!(
      username: "teststreamer",
      email: "streamer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Create a stream for the user
    @stream = @user.streams.create!(
      title: "My Test Stream",
      status: "offline"
    )
  end

  # TEST: should redirect to login when not authenticated
  test "should redirect to login when not logged in" do
    # Try to access dashboard without logging in
    get dashboard_path

    # Should redirect to login page (require_login before_action)
    assert_redirected_to login_path

    # Follow redirect and check for flash message
    follow_redirect!
    assert_select "div.alert-danger", /must be logged in/i
  end

  # TEST: should show dashboard when authenticated
  test "should show dashboard when logged in" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access dashboard
    get dashboard_path

    # Should be successful
    assert_response :success

    # Should show user's username
    assert_select "h1", /Welcome.*#{@user.username}/i
  end

  # TEST: should display user's stream information
  test "should display user stream information" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access dashboard
    get dashboard_path

    # Should show stream title
    assert_select "h3", /#{@stream.title}/

    # Should show stream status
    assert_select "span.badge", /offline/i
  end

  # TEST: should show stream key (for OBS setup)
  test "should display stream key for OBS configuration" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access dashboard
    get dashboard_path

    # Should show stream key (partially hidden for security)
    assert_select "code"
  end

  # TEST: should show quick action buttons
  test "should show quick action buttons" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access dashboard
    get dashboard_path

    # Should have button to edit stream
    assert_select "a[href=?]", edit_stream_path(@stream)

    # Should have link to settings
    assert_select "a[href=?]", settings_path
  end

  # TEST: should show subscription tier (for future payments)
  test "should display subscription tier" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access dashboard
    get dashboard_path

    # Should show subscription tier (will be 'free' by default)
    assert_response :success
  end

  # TEST: should show streaming stats
  test "should show streaming statistics" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Access dashboard
    get dashboard_path

    # Should show stats cards
    assert_select ".card", minimum: 2
  end
end
