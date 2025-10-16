# app/controllers/v1/authentication_controller.rb
module V1
  class AuthenticationController < ApplicationController
    include ActionController::Cookies
    skip_before_action :authenticate_request!, only: [:login, :refresh]

    # =========================================================================
    # POST /v1/login
    # =========================================================================
    def login
      user_params = params[:user] || {}
      @user = User.find_by(email: user_params[:email])

      if @user&.authenticate(user_params[:password])
        access_token = JsonWebToken.encode(user_id: @user.id)

        # Generate secure random refresh token
        raw_refresh_token = AuthenticationService.generate_secure_token

        # Store hashed version in DB
        @user.refresh_tokens.create!(
          token_hash: AuthenticationService.hash_token(raw_refresh_token),
          expires_at: 30.days.from_now
        )

        # ✅ Set refresh token as HttpOnly cookie (direct header write)
        response.set_cookie(
          :refresh_token,
          value: raw_refresh_token,
          httponly: true,
          path: '/',
          expires: 30.days.from_now
        )

        render json: { access_token: access_token }, status: :ok
      else
        render json: { error: 'Invalid email or password' }, status: :unauthorized
      end
    end

    # =========================================================================
    # POST /v1/refresh
    # =========================================================================
    def refresh
      raw_refresh_token = request.cookies['refresh_token']

      unless raw_refresh_token.present?
        return render json: { error: 'Unauthorized', message: 'Refresh token missing or corrupt' }, status: :unauthorized
      end

      token_hash = AuthenticationService.hash_token(raw_refresh_token)
      old_token = RefreshToken.active.find_by(token_hash: token_hash)

      unless old_token
        # Clear invalid/expired cookie
        response.delete_cookie(:refresh_token, path: '/')
        return render json: { error: 'Unauthorized', message: 'Refresh token missing or corrupt' }, status: :unauthorized
      end

      # ✅ Revoke old refresh token
      old_token.revoke!

      # ✅ Issue a new one
      new_raw_token = AuthenticationService.generate_secure_token
      old_token.user.refresh_tokens.create!(
        token_hash: AuthenticationService.hash_token(new_raw_token),
        expires_at: 30.days.from_now
      )

      # ✅ Set new HttpOnly cookie
      response.set_cookie(
        :refresh_token,
        value: new_raw_token,
        httponly: true,
        path: '/',
        expires: 30.days.from_now
      )

      new_access_token = JsonWebToken.encode(user_id: old_token.user.id)
      render json: { access_token: new_access_token }, status: :ok
    end

    # =========================================================================
    # DELETE /v1/logout
    # =========================================================================
    def logout
      raw_refresh_token = request.cookies['refresh_token']

      if raw_refresh_token.present?
        token_hash = AuthenticationService.hash_token(raw_refresh_token)
        token = RefreshToken.find_by(token_hash: token_hash)
        token&.revoke!
      end

      # ✅ Explicitly clear refresh_token cookie for client
      response.delete_cookie(:refresh_token, path: '/')

      head :no_content
    end
  end
end
