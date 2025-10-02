# config/routes.rb
# This file defines all application routes (URL patterns and their handlers)
# Learn more about routing: https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  get "pages/landing"
  # AUTHENTICATION ROUTES
  # These routes handle user signup, login, and logout
  # Learn more about resources: https://guides.rubyonrails.org/routing.html#resource-routing-the-rails-default

  # Session routes (login/logout)
  # resource :session creates routes for managing a single session (not plural)
  # This creates: new_session_path, session_path, etc.
  # only: [:new, :create, :destroy] limits to just these actions
  resource :session, only: [ :new, :create, :destroy ]

  # Registration routes (signup)
  # resource :registration creates routes for user signup
  resource :registration, only: [ :new, :create ]

  # Named routes for better readability
  # get "/login" maps to sessions#new (the login form)
  # to: specifies the controller#action
  # as: creates a named route helper (login_path, login_url)
  get "/login", to: "sessions#new", as: :login

  # post "/login" maps to sessions#create (processes login)
  post "/login", to: "sessions#create"

  # delete "/logout" maps to sessions#destroy (logs user out)
  # RESTful convention: DELETE is used to destroy resources
  delete "/logout", to: "sessions#destroy", as: :logout

  # get "/signup" maps to registrations#new (the signup form)
  get "/signup", to: "registrations#new", as: :signup

  # post "/signup" maps to registrations#create (processes signup)
  post "/signup", to: "registrations#create"

  # DASHBOARD ROUTES
  # Main user dashboard after login
  get "/dashboard", to: "dashboard#index", as: :dashboard

  # SETTINGS ROUTES
  # User settings and preferences
  get "/settings", to: "settings#index", as: :settings
  patch "/settings/profile", to: "settings#update_profile", as: :update_profile
  patch "/settings/password", to: "settings#update_password", as: :update_password

  # STREAM ROUTES
  # Routes for managing user streams
  resources :streams, only: [ :index, :show, :edit, :update ]

  # INTEGRATION ROUTES
  # Routes for third-party integrations (Steam, Discord, etc.)
  namespace :integrations do
    integration_routes :steam, controller: 'steam'
    integration_routes :discord, controller: 'discord'
    integration_routes :battlenet, controller: 'battlenet'
    integration_routes :riot, controller: 'riot'
    integration_routes :twitter, controller: 'twitter'
    integration_routes :youtube, controller: 'youtube'
    integration_routes :stripe, controller: 'stripe'
    # OBS uses WebSocket connection, different routing
    get 'obs/setup', to: 'obs#setup', as: :obs_setup
    post 'obs/connect', to: 'obs#connect', as: :obs_connect
    delete 'obs/disconnect', to: 'obs#disconnect', as: :obs_disconnect
  end

  # HEALTH CHECK ROUTE
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # ROOT ROUTE
  # Defines the root path route ("/")
  # After login, users go to dashboard; logged-out users see landing page
  root "dashboard#index"
end
