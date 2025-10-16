Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # API Namespace
  namespace :v1 do
    # Authentication endpoints (Login)
    # post 'auth/login', to: 'authentication#login'
    post 'login', to: 'sessions#create'
    post 'refresh', to: 'sessions#refresh'
    delete 'logout', to: 'sessions#destroy'

    # User registration endpoint
    resources :users, only: [:create]

    resources :events do
      resources :tickets, only: [:index, :create, :show] do
        member do
          patch :check_in
        end
      end
    end

    get 'users/profile', to: 'users#show'
    put 'users/profile', to: 'users#update'

    # Team members management
    resources :team_members do
      member do
        patch :toggle_status
      end
    end

    # Other resources to be added here
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
