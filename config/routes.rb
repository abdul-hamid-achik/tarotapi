Rails.application.routes.draw do
  mount_devise_token_auth_for "User", at: "api/v1/auth"
  # API documentation
  mount Rswag::Ui::Engine => "/docs"
  mount Rswag::Api::Engine => "/api"

  # Pay webhooks and checkout routes
  mount Pay::Engine, at: "/pay", as: "pay_engine"

  # Make Swagger UI the default documentation interface
  root to: redirect("/docs")

  # Public health check endpoint for load balancers
  get "health" => "health#index", as: :health_check

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      # Protected health check endpoints (require authentication)
      get "health/detailed", to: "health#detailed"
      get "health/database", to: "health#database"

      # OAuth endpoints
      get "oauth/authorize", to: "oauth#authorize"
      post "oauth/token", to: "oauth#token"

      # Organization management
      resources :organizations do
        member do
          post "members", to: "organizations#add_member"
          delete "members/:user_id", to: "organizations#remove_member"
          get "usage", to: "organizations#usage"
          get "analytics", to: "organizations#analytics"
        end

        resources :api_keys, only: [ :index, :show, :create, :update, :destroy ]
      end

      # Personal API Keys management
      resources :api_keys, only: [ :index, :show, :create ] do
        member do
          delete :revoke
        end
      end

      # Authentication routes
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      get "auth/profile", to: "auth#profile"
      post "auth/agent", to: "auth#create_agent"

      # Subscription routes
      resources :subscriptions, only: [ :create, :show ] do
        member do
          post :cancel
        end
        collection do
          get :payment_methods
          post :attach_payment_method
          delete :detach_payment_method
        end
      end

      resources :users, only: [ :create, :show ]
      resources :cards, only: [ :index, :show ]
      # Add TarotCard routes for testing
      resources :tarot_cards, only: [ :index, :show ]
      resources :card_readings, only: [ :create, :index, :show ] do
        collection do
          post :interpret
        end
      end
      resources :spreads, only: [ :create, :index, :show ]
      resources :readings, only: [ :create, :index, :show ] do
        member do
          post :interpret
          post :interpret_streaming
          post :numerology
          get :symbolism
        end
      end
      # Add ReadingSession routes for testing
      resources :reading_sessions, only: [ :create, :index, :show ]

      # Arcana explanation endpoint
      get "arcana/:arcana_type", to: "readings#arcana_explanation"
      get "arcana/:arcana_type/:specific_card", to: "readings#arcana_explanation"

      # Card combination analysis
      get "card_combinations/:card_id1/:card_id2", to: "card_readings#analyze_combination"

      resource :seance, only: [ :create ] do
        get :validate, on: :collection
      end

      resources :spreads, only: [ :index ]

      resources :usage, only: [ :index ] do
        collection do
          get :daily
        end
      end
    end
  end
end
