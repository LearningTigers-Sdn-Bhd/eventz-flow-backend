Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # API Namespace
  namespace :v1 do
    # Authentication endpoints (Login)
    # post 'auth/login', to: 'authentication#login'
    post 'login', to: 'sessions#create'

    # User registration endpoint
    resources :users, only: [:create]

    resources :events

    get 'users/me', to: 'users#show'
    put 'users/me', to: 'users#update'

    # Other resources to be added here
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
