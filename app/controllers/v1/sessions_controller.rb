# app/controllers/v1/sessions_controller.rb
class V1::SessionsController < ApplicationController
  skip_before_action :authenticate_request!, only: %i[create refresh]

  # POST /v1/login
  def create
    user = User.find_by(email: session_params[:email].downcase)
    unless user&.authenticate(session_params[:password])
      raise CustomError::Unauthorized.new('Invalid email or password')
    end

    # Check if user account is active
    unless user.active?
      raise CustomError::Unauthorized.new('Your account has been deactivated. Please contact support.')
    end

    access_token = JsonWebToken.encode(user_id: user.id, exp: 15.minutes.from_now)

    raw_refresh_token  = AuthenticationService.generate_secure_token
    refresh_token_hash = AuthenticationService.hash_token(raw_refresh_token)

    user.refresh_tokens.create!(
      token_hash:  refresh_token_hash,
      expires_at:  7.days.from_now
    )

    # ✅ Manually add Set-Cookie header (bypasses ActionDispatch::Cookies)
    response.set_header(
      'Set-Cookie',
      "refresh_token=#{raw_refresh_token}; " \
      "Path=/; HttpOnly; SameSite=Lax; Expires=#{7.days.from_now.utc.httpdate}"
    )

    render json: {
      access_token: access_token,
      user: user.slice(:id, :full_name, :email, :role)
    }, status: :ok
  end

  # POST /v1/refresh
  def refresh
    raw_token = request.cookies['refresh_token']
    raise CustomError::Unauthorized.new('Refresh token missing or corrupt') unless raw_token

    token_hash = AuthenticationService.hash_token(raw_token)
    token_record = RefreshToken.find_by(token_hash: token_hash)
    unless token_record&.active?
      clear_refresh_cookie
      raise CustomError::Unauthorized.new('Invalid or expired refresh token. Please log in again.')
    end

    token_record.revoke!
    user = token_record.user

    new_access_token = JsonWebToken.encode(user_id: user.id, exp: 15.minutes.from_now)
    new_raw_token    = AuthenticationService.generate_secure_token
    new_token_hash   = AuthenticationService.hash_token(new_raw_token)

    user.refresh_tokens.create!(
      token_hash:  new_token_hash,
      expires_at:  7.days.from_now
    )

    response.set_header(
      'Set-Cookie',
      "refresh_token=#{new_raw_token}; " \
      "Path=/; HttpOnly; SameSite=Lax; Expires=#{7.days.from_now.utc.httpdate}"
    )

    render json: { access_token: new_access_token }, status: :ok
  end

  # DELETE /v1/logout
  def destroy
    raw_token = request.cookies['refresh_token']
    if raw_token
      token_hash = AuthenticationService.hash_token(raw_token)
      current_user.refresh_tokens.find_by(token_hash: token_hash)&.revoke!
    end
    clear_refresh_cookie
    head :no_content
  end

  private

    def clear_refresh_cookie
        response.set_header(
            'Set-Cookie',
            "refresh_token=; Path=/; HttpOnly; SameSite=Lax; expires=Thu, 01 Jan 1970 00:00:00 GMT"
        )
    end

  def session_params
    params.require(:user).permit(:email, :password)
  rescue ActionController::ParameterMissing
    raise CustomError::Unauthorized.new('Missing login credentials.')
  end
end
