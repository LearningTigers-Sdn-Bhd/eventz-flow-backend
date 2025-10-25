# frozen_string_literal: true

# Concern for JWT authentication in API controllers
module Authenticable
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
    end

    private

    # Authenticate user from JWT token or API Key
    def authenticate_user!
      header = request.headers['Authorization']
      return render_unauthorized unless header

      # Try JWT first (standard Bearer)
      if header.start_with?('Bearer ')
        token = header.split(' ').last
        begin
          payload = JwtService.decode(token)
          @current_user = User.find_by(id: payload[:user_id], jti: payload[:jti])
          return if @current_user.present?
        rescue CustomError::Unauthorized => e
          # Check if it's a token expiration error
          if e.message.include?('expired')
            render_token_expired(e)
            return
          else
            # fallback to API key check next
          end
        end
      end

      # Try raw API Key (no Bearer prefix) - use BCrypt-based authentication
      if header.length > 30 && !header.include?(' ')
        @current_user = ApiKey.authenticate_by_key(header)
        return if @current_user.present?
      end

      render_unauthorized
    end

    # Get current authenticated user
    def current_user
      @current_user
    end

    # Extract JWT token from Authorization header
    def extract_token_from_header
      header = request.headers['Authorization']
      return nil unless header

      header.split.last if header.start_with?('Bearer ')
    end

    # Render unauthorized error
    def render_unauthorized(exception = nil)
      message = exception&.message || 'Unauthorized'
      render json: { success: false, message: message, errors: [] }, status: :unauthorized
    end

    # Render token expired error
    def render_token_expired(_exception)
      render json: { success: false, message: 'Token has expired', errors: [] }, status: :unauthorized
    end
  end
