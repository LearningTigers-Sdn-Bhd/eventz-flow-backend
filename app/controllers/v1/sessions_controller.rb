class V1::SessionsController < ApplicationController
  # Skip JWT check for the login action
  skip_before_action :authenticate_request!, only: [:create]

  # POST /v1/login
  def create
    # Use lowercase email for consistent lookup
    user = User.find_by(email: params[:email].downcase)

    if user&.authenticate(params[:password])
      # Issue JWT token on successful authentication
      token = JsonWebToken.encode(user_id: user.id)
      
      # Return user data and token
      render json: { token: token, user: user.slice(:id, :full_name, :email, :role) }, status: :ok
    else
      # Raise CustomError::Unauthorized for 401 response
      raise CustomError::Unauthorized.new('Invalid email or password')
    end
  end
end