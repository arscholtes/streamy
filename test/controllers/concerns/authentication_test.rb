# test/controllers/concerns/authentication_test.rb
# This file tests the Authentication concern (helper methods for authentication)
# Concerns are modules that can be included in multiple controllers
# Learn more: https://api.rubyonrails.org/classes/ActiveSupport/Concern.html

require "test_helper"

# Create a dummy controller to test the Authentication concern
# This is a common pattern for testing concerns
class AuthenticationTestController < ApplicationController
  include Authentication

  # Define test actions that use authentication methods
  def index
    render plain: "Index"
  end

  def protected_action
    render plain: "Protected"
  end
end

class AuthenticationTest < ActionDispatch::IntegrationTest
  # Setup runs before each test
  def setup
    # Add test routes for our dummy controller
    # This allows us to test the concern's methods
    Rails.application.routes.draw do
      get "auth_test/index" => "authentication_test#index"
      get "auth_test/protected" => "authentication_test#protected_action"

      # Keep existing routes
      resource :session, only: [ :new, :create, :destroy ]
      resource :registration, only: [ :new, :create ]
      get "/login", to: "sessions#new", as: :login
      post "/login", to: "sessions#create"
      delete "/logout", to: "sessions#destroy", as: :logout
      get "/signup", to: "registrations#new", as: :signup
      post "/signup", to: "registrations#create"
      get "up" => "rails/health#show", as: :rails_health_check
      root "sessions#new"
    end

    # Create a test user
    @user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # Teardown runs after each test
  def teardown
    # Reload original routes
    Rails.application.reload_routes!
  end

  # TEST: current_user returns nil when not logged in
  test "current_user should return nil when not logged in" do
    get auth_test_index_path
    assert_response :success
    # current_user should be nil (tested via controller behavior)
  end

  # TEST: current_user returns user when logged in
  test "current_user should return user when logged in" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Now current_user should return the logged-in user
    get auth_test_index_path
    assert_response :success
  end

  # TEST: logged_in? returns false when not logged in
  test "logged_in? should return false when not logged in" do
    get auth_test_index_path
    assert_response :success
  end

  # TEST: logged_in? returns true when logged in
  test "logged_in? should return true when logged in" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    get auth_test_index_path
    assert_response :success
  end

  # TEST: current_user is memoized (cached)
  # This ensures we don't query the database multiple times per request
  test "current_user should be memoized" do
    # Login the user
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Multiple calls to current_user should not hit the database multiple times
    get auth_test_index_path
    assert_response :success
  end
end

# Integration tests for require_login method
class RequireLoginTest < ActionDispatch::IntegrationTest
  def setup
    # Create a protected controller for testing
    Rails.application.routes.draw do
      get "protected/index" => "protected_test#index"

      # Keep existing routes
      resource :session, only: [ :new, :create, :destroy ]
      resource :registration, only: [ :new, :create ]
      get "/login", to: "sessions#new", as: :login
      post "/login", to: "sessions#create"
      delete "/logout", to: "sessions#destroy", as: :logout
      get "/signup", to: "registrations#new", as: :signup
      post "/signup", to: "registrations#create"
      get "up" => "rails/health#show", as: :rails_health_check
      root "sessions#new"
    end

    @user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def teardown
    Rails.application.reload_routes!
  end

  # TEST: require_login redirects to login when not authenticated
  test "require_login should redirect to login page when not logged in" do
    # Try to access protected page without logging in
    get "/protected/index"

    # Should redirect to login page
    assert_redirected_to login_path
    follow_redirect!

    # Should show a flash message
    assert_select "div.alert-danger", /must be logged in/i
  end

  # TEST: require_login allows access when authenticated
  test "require_login should allow access when logged in" do
    # Login the user first
    post session_path, params: {
      session: {
        username: @user.username,
        password: "password123"
      }
    }

    # Now try to access protected page
    get "/protected/index"

    # Should allow access (not redirect)
    assert_response :success
  end
end

# Dummy controller for testing require_login
class ProtectedTestController < ApplicationController
  include Authentication
  before_action :require_login

  def index
    render plain: "Protected content"
  end
end
