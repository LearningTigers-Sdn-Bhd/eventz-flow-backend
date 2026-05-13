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
      return unless header

      @authenticated_via_api_key = false

      if header.start_with?('Bearer ')
        token = header.split(' ').last
        begin
          payload = JwtService.decode(token)
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

      if header.length > 30 && !header.include?(' ')
        api_key = ApiKey.authenticate_by_key(header)
        if api_key.present?
          @current_user = api_key.user
          @current_api_key = api_key
          @authenticated_via_api_key = true
          return
        end
      end

      render_unauthorized
    end

    attr_reader :authenticated_via_api_key, :current_api_key

    def authenticate_user!
      header = request.headers['Authorization']
      @authenticated_via_api_key = false
      return render_unauthorized unless header

      if header.start_with?('Bearer ')
        token = header.split(' ').last
        begin
          payload = JwtService.decode(token)
          session = UserSession.find_by(jti: payload[:jti], user_id: payload[:user_id])
          if session && session.active?
             @current_user = session.user
             session.touch!
             return if @current_user.present?
          else
             return render_unauthorized(CustomError::Unauthorized.new('Session invalid or expired'))
          end
        rescue CustomError::Unauthorized => e
          if e.message.include?('expired')
            render_token_expired(e)
            return
          end
        end
      end

      if header.length > 30 && !header.include?(' ')
        api_key = ApiKey.authenticate_by_key(header)
        if api_key.present?
          @current_user = api_key.user
          @current_api_key = api_key
          @authenticated_via_api_key = true
          return
        end
      end

      render_unauthorized
    end

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

    def current_user
      @current_user
    end

    def extract_token_from_header
      header = request.headers['Authorization']
      return nil unless header
      header.split.last if header.start_with?('Bearer ')
    end

    def render_unauthorized(exception = nil)
      message = exception&.message || 'Unauthorized'
      render json: { success: false, message: message, errors: [] }, status: :unauthorized
    end

    def render_token_expired(_exception)
      render json: { success: false, message: 'Token has expired', errors: [] }, status: :unauthorized
    end
  end
