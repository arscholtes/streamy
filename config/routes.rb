# config/routes.rb
# This file defines all application routes (URL patterns and their handlers)
# Learn more about routing: https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  get "pages/landing"

  # USER PROFILE ROUTES
  # Public user profiles
  resources :users, only: [:show]
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
  resources :streams, only: [ :index, :show, :edit, :update ] do
    # Nested chat messages routes
    resources :chat_messages, only: [ :create ]
  end

  # SUBSCRIPTION ROUTES
  # Platform subscription management
  resources :subscriptions, only: [] do
    collection do
      get :new
      post :create
    end
  end

  resource :subscription, only: [:show] do
    get :success, on: :collection
    post :reactivate
    post :change_plan
    delete :cancel
    get :portal
  end

  # DONATION ROUTES
  # Streamer tips and donations
  resources :donations, only: [:index]
  get '/users/:username/donate', to: 'donations#new', as: :new_user_donation
  post '/users/:username/donate', to: 'donations#create', as: :user_donations
  get '/users/:username/donate/success', to: 'donations#success', as: :donation_success

  # WEBHOOK ROUTES
  # Stripe webhook endpoint
  post '/webhooks/stripe', to: 'webhooks#stripe'

  # INTEGRATION ROUTES
  # Routes for third-party integrations (Steam, Discord, etc.)
  namespace :integrations do
    # Tier 1 Integrations
    integration_routes :steam, controller: 'steam'
    integration_routes :discord, controller: 'discord'
    integration_routes :battlenet, controller: 'battlenet'
    integration_routes :riot, controller: 'riot'
    integration_routes :twitter, controller: 'twitter'
    integration_routes :youtube, controller: 'youtube'
    integration_routes :stripe, controller: 'stripe'

    # Tier 2 Integrations
    integration_routes :epic, controller: 'epic'
    integration_routes :xbox, controller: 'xbox'
    integration_routes :playstation, controller: 'playstation'
    integration_routes :spotify, controller: 'spotify'
    integration_routes :tiktok, controller: 'tiktok'
    integration_routes :instagram, controller: 'instagram'
    integration_routes :twitch, controller: 'twitch'
    integration_routes :paypal, controller: 'paypal'
    integration_routes :google_analytics, controller: 'google_analytics'

    # OpenAI uses API key, not OAuth
    get 'openai/connect', to: 'openai#connect', as: :openai_connect
    post 'openai/create', to: 'openai#create', as: :openai_create
    delete 'openai/disconnect', to: 'openai#disconnect', as: :openai_disconnect

    # OBS uses WebSocket connection, different routing
    get 'obs/setup', to: 'obs#setup', as: :obs_setup
    post 'obs/connect', to: 'obs#connect', as: :obs_connect
    delete 'obs/disconnect', to: 'obs#disconnect', as: :obs_disconnect
  end

  # API ROUTES
  # Discord Bot API endpoints
  namespace :api do
    namespace :v1 do
      # User endpoints
      get 'users/discord/:discord_id', to: 'users#show_by_discord_id'
      post 'users', to: 'users#create'

      # Loyalty points endpoints
      get 'users/:user_id/loyalty_points', to: 'loyalty_points#show'
      post 'users/:user_id/loyalty_points/add', to: 'loyalty_points#add'
      post 'users/:user_id/loyalty_points/spend', to: 'loyalty_points#spend'
      get 'loyalty_points/leaderboard', to: 'loyalty_points#leaderboard'

      # Achievement endpoints
      get 'achievements', to: 'achievements#index'
      get 'users/:user_id/achievements', to: 'achievements#user_achievements'
      post 'users/:user_id/achievements', to: 'achievements#award'

      # VC Queue endpoints
      get 'vc_queue', to: 'vc_queue#index'
      post 'vc_queue/join', to: 'vc_queue#join'
      post 'vc_queue/leave/:user_id', to: 'vc_queue#leave'
      post 'vc_queue/next', to: 'vc_queue#next_in_queue'

      # Mini-games endpoints
      post 'mini_games/record', to: 'mini_games#record'
      get 'users/:user_id/mini_games/stats', to: 'mini_games#stats'

      # Moderation endpoints
      post 'moderation/warn', to: 'moderation#warn'
      get 'moderation/warnings/:discord_id', to: 'moderation#warnings'
      delete 'moderation/warnings/:discord_id', to: 'moderation#clear_warnings'
      post 'moderation/mute', to: 'moderation#mute'
      post 'moderation/unmute', to: 'moderation#unmute'
      get 'moderation/mutes/active', to: 'moderation#active_mutes'
      get 'moderation/mutes/:discord_id', to: 'moderation#check_mute'
      post 'moderation/action', to: 'moderation#log_action'
      get 'moderation/actions', to: 'moderation#actions'
    end
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
