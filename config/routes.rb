Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'api/v1/auth'
  # api documentation
  mount Rswag::Api::Engine => "/api"

  # Pay webhooks and checkout routes
  mount Pay::Engine, at: '/pay', as: 'pay_engine'

  # make redoc the default documentation interface
  root to: redirect("/docs")
  get "/docs", to: "redoc#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "health" => "health#show", as: :health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      # API Keys management
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

      # Arcana explanation endpoint
      get "arcana/:arcana_type", to: "readings#arcana_explanation"
      get "arcana/:arcana_type/:specific_card", to: "readings#arcana_explanation"

      # Card combination analysis
      get "card_combinations/:card_id1/:card_id2", to: "card_readings#analyze_combination"

      resource :seance, only: [ :create ] do
        get :validate, on: :collection
      end

      resources :spreads, only: [ :index ]
    end
  end
end
