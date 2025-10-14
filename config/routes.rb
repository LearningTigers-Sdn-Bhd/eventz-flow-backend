Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # API Namespace
  namespace :v1 do
    # Authentication endpoints (Login)
    post 'auth/login', to: 'authentication#login'

    # User registration endpoint
    resources :users, only: [:create]

    # Other resources to be added here
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
