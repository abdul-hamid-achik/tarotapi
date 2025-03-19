Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/docs"
  mount Rswag::Api::Engine => "/api"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "health" => "health#show", as: :health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      # Authentication routes
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      get "auth/profile", to: "auth#profile"

      # Subscription routes
      resources :subscriptions, only: [ :create, :show ] do
        member do
          post :cancel
        end
      end

      resources :users, only: [ :create, :show ]
      resources :tarot_cards, only: [ :index, :show ]
      resources :card_readings, only: [ :create, :index, :show ] do
        collection do
          post :interpret
        end
      end
      resources :spreads, only: [ :create, :index, :show ]
      resources :reading_sessions, only: [ :create, :index, :show ] do
        member do
          post :interpret
          post :numerology
          get :symbolism
        end
      end

      # Arcana explanation endpoint
      get "arcana/:arcana_type", to: "reading_sessions#arcana_explanation"
      get "arcana/:arcana_type/:specific_card", to: "reading_sessions#arcana_explanation"

      # Card combination analysis
      get "card_combinations/:card_id1/:card_id2", to: "card_readings#analyze_combination"

      resource :seance, only: [ :create ] do
        get :validate, on: :collection
      end

      resources :reading_sessions
      resources :spreads, only: [ :index ]
    end
  end
end
