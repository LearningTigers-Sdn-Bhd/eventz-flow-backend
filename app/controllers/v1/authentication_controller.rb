# app/controllers/v1/authentication_controller.rb
class V1::AuthenticationController < ApplicationController
  skip_before_action :authenticate_request!, only: %i[login register logout]

  # POST /v1/login
  def login
    # Find user by email
    user = User.find_by(email: session_params[:email].downcase)

    # Check if user account is active
    unless user.active?
      raise CustomError::Unauthorized.new('Your account has been deactivated. Please contact support.')
    end

    # Check if user credentials are valid
    if user&.authenticate(session_params[:password])
      # Generate access token
      access_token = JsonWebToken.encode(user_id: user.id)

      # Generate refresh token
      refresh_token = AuthenticationService.generate_secure_token

      # If user has a refresh token, revoke it
      if user.refresh_tokens.active.exists?
        user.refresh_tokens.active.first.revoke!
      end

      # Create new refresh token
      user.refresh_tokens.create!(
        token_hash: refresh_token,
        expires_at: 7.days.from_now
      )
    else
      raise CustomError::Unauthorized.new('Invalid email or password')
    end

    render json: {
      access_token: access_token,
      refresh_token: refresh_token,
      user: user.slice(:id, :full_name, :email, :role)
    }, status: :ok
  end

  def register
    @user = User.new(user_params)

    authorize @user, :create?
    if @user.save
      access_token = JsonWebToken.encode(user_id: @user.id)
      refresh_token = AuthenticationService.generate_secure_token

      @user.refresh_tokens.create!(
        token_hash: refresh_token,
        expires_at: 7.days.from_now
      )

      render json: {
        access_token: access_token,
        refresh_token: refresh_token,
        user: @user.slice(:id, :full_name, :email, :role)
      }, status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /v1/logout
  def logout
    # Find refresh token record
    token_record = RefreshToken.find_by(token_hash: refresh_token)

    unless token_record
      raise CustomError::Unauthorized.new('User not found')
    end

    # Revoke refresh token
    token_record.revoke!

    # Clear refresh cookie
    clear_refresh_cookie
    render json: { message: 'Logged out successfully' }, status: :ok
  end

  private

    def clear_refresh_cookie
        # Clear refresh cookie if it exists
        response.delete_cookie(:refresh_token, path: '/')
    end


    def session_params
      params.require(:user).permit(:email, :password)
    rescue ActionController::ParameterMissing
      raise CustomError::Unauthorized.new('Missing login credentials.')
    end

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :phone)
    end

    def refresh_token
      request.headers['HTTP_X_REFRESH_TOKEN'] ||
          request.headers['HTTP_X_REFRESH_TOKEN'] ||
          cookies['refresh_token']
    end
end
