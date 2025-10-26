# app/controllers/v1/authentication_controller.rb
module V1
  class AuthenticationController < ApplicationController
    skip_before_action :authenticate_user!, only: %i[login register refresh_token]

    def register
      @user = User.new(register_params)
      authorize @user, :create?

      if @user.save
        tokens = JwtService.generate_tokens(@user)

        success_response(
          data: {
            user: @user.slice(:id, :full_name, :email, :role),
            **tokens
          },
          message: 'User registered successfully',
          status: :created
        )
      else
        error_response(message: 'Validation Error', errors: format_validation_errors(@user), status: :unprocessable_content)
      end
    end

  # POST /v1/login
  def login
    email = login_params[:email]
    return error_response(message: 'Email is required', errors: [{ field: 'email', message: 'Email is required' }], status: :unprocessable_content) if email.blank?

    user = User.find_by(email: email.downcase)

    # Check if user exists, is active, and credentials are valid
    if user&.active? && user&.authenticate(login_params[:password])
      tokens = JwtService.generate_tokens(user)

      success_response(
        data: {
          user: user.slice(:id, :full_name, :email, :role),
          **tokens
        },
        message: 'Login successful',
        status: :ok
      )
    else
      # Provide specific error messages based on the failure reason
      if user.nil?
        error_response(
          message: 'Authentication failed',
          errors: [{ field: 'email', message: 'Email not found' }],
          status: :unauthorized
        )
      elsif !user.active?
        error_response(
          message: 'Authentication failed',
          errors: [{ field: 'account', message: 'Account is inactive' }],
          status: :unauthorized
        )
      else
        error_response(
          message: 'Authentication failed',
          errors: [{ field: 'password', message: 'Invalid password' }],
          status: :unauthorized
        )
      end
    end
  end

  # DELETE /v1/logout
  def logout
    if current_user
      current_user.update!(jti: SecureRandom.uuid)
      success_response(
        message: 'Logged out successfully',
        status: :ok
      )
    else
      error_response(
        message: 'Logout failed',
        errors: [{ field: 'user', message: 'User not found or not authenticated' }],
        status: :unauthorized
      )
    end
  end

  def refresh_token
    refresh_token = params[:refresh_token]
    unless refresh_token
      return error_response(message: 'Refresh token is required', errors: [{ field: 'refresh_token', message: 'Refresh token is required' }], status: :unprocessable_content)
    end

    tokens = JwtService.refresh_access_token(refresh_token)
    success_response(
      data: tokens,
      message: 'Access token refreshed successfully'
    )
  rescue CustomError::Unauthorized => e
    return error_response(message: 'Invalid refresh token', errors: [{ field: 'refresh_token', message: e.message }], status: :unauthorized)
  end

  private

  def login_params
    # Handle both nested and flat parameter formats
    if params[:user].present?
      params.require(:user).permit(:email, :password)
    else
      params.permit(:email, :password)
    end
  end

  def register_params
    user_params = params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :phone)
    # Ensure email is downcased
    user_params[:email] = user_params[:email].downcase if user_params[:email].present?
    user_params
  end
end
end
