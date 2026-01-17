# frozen_string_literal: true

# Concern for JWT authentication in API controllers
module Authenticable
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
      before_action :require_verified_email!
    end

    class_methods do
      def skip_default_authentication(options = {})
        skip_before_action :authenticate_user!, options
      end
    end

    private

    # Authenticate user only if token/key is provided
    def authenticate_user_if_token_present
      header = request.headers['Authorization']
      return unless header # Allow anonymous access ONLY if no header is present

      @authenticated_via_api_key = false

      # Try JWT first
      if header.start_with?('Bearer ')
        token = header.split(' ').last
        begin
          payload = JwtService.decode(token)
          
          # Session-based auth
          session = UserSession.find_by(jti: payload[:jti], user_id: payload[:user_id])
          
          if session && session.active?
             @current_user = session.user
             session.touch!
             return if @current_user.present?
          end
        rescue CustomError::Unauthorized => e
           if e.message.include?('expired')
            render_token_expired(e)
            return
           end
        end
      end

      # Try API Key (if not Bearer or if Bearer failed/was ignored)
      if header.length > 30 && !header.include?(' ')
        @current_user = ApiKey.authenticate_by_key(header)
        if @current_user.present?
          @authenticated_via_api_key = true
          return
        end
      end

      # If header was present but authentication failed
      render_unauthorized
    end

    # Track if user was authenticated via API key
    attr_reader :authenticated_via_api_key

    # Authenticate user from JWT token or API Key
    def authenticate_user!
      header = request.headers['Authorization']
      @authenticated_via_api_key = false
      return render_unauthorized unless header

      # Try JWT first (standard Bearer)
      if header.start_with?('Bearer ')
        token = header.split(' ').last
        begin
          payload = JwtService.decode(token)
          
          # Session-based auth
          session = UserSession.find_by(jti: payload[:jti], user_id: payload[:user_id])
          
          if session && session.active?
             @current_user = session.user
             session.touch!
             return if @current_user.present?
          else
             # Session invalid or revoked
             return render_unauthorized(CustomError::Unauthorized.new('Session invalid or expired'))
          end
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
        if @current_user.present?
          @authenticated_via_api_key = true
          return
        end
      end

      render_unauthorized
    end

    # Require email verification unless authenticated via API key
    def require_verified_email!
      return if authenticated_via_api_key
      return unless @current_user.present?

      unless @current_user.email_verified?
        render json: {
          success: false,
          message: 'Email verification required',
          errors: [{ field: 'email_verification', message: 'Please verify your email before accessing this resource' }]
        }, status: :forbidden
      end
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