# frozen_string_literal: true

# Concern for JWT authentication in API controllers
module Authenticable
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
      before_action :require_verified_email!
      before_action :enforce_api_key_event_scope!
      before_action :enforce_api_key_method_scope!
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

    # When the request is authenticated via an event-scoped API key, every
    # request must target that exact event. Without this gate, an org_owner
    # who creates an event-scoped key still inherits "scope.all" in many
    # Pundit scopes (e.g. VoucherPolicy::Scope) and could read data across
    # other events using the key.
    #
    # Rules:
    #   - If api_key has no event_id (account-wide key), do nothing.
    #   - If the request includes an event_id-shaped param, it must match
    #     api_key.event_id.
    #   - If the request does not target an event at all (e.g. account-level
    #     listings like /v1/vouchers without filter), reject — event-scoped
    #     keys must not be used for cross-event endpoints.
    def enforce_api_key_event_scope!
      return unless @authenticated_via_api_key
      return unless @current_api_key&.event_id.present?

      requested_event_id = api_key_request_event_id
      if requested_event_id.nil?
        return render json: {
          success: false,
          message: 'This API key is scoped to a single event. Provide event_id in the URL or query.',
          errors: []
        }, status: :forbidden
      end

      return if requested_event_id.to_s == @current_api_key.event_id.to_s

      render json: {
        success: false,
        message: 'This API key is not authorized for the requested event.',
        errors: []
      }, status: :forbidden
    end

    # Gate every API-key request by the key's scope. The scope is verb-based:
    # read_only rejects POST/PUT/PATCH/DELETE; check_in additionally allows
    # POST (so /v1/scan/:public_id/check_in works); read_write allows all.
    # This sits *after* enforce_api_key_event_scope! so we've already
    # confirmed the key is targeting the right event before we check method.
    def enforce_api_key_method_scope!
      return unless @authenticated_via_api_key
      return if @current_api_key&.allows_method?(request.request_method)

      render json: {
        success: false,
        message: "This API key is read-only and cannot perform #{request.request_method} requests.",
        errors: []
      }, status: :forbidden
    end

    # Best-effort extraction of an event identifier from a request. Returns
    # the integer event_id when one can be resolved, otherwise nil.
    def api_key_request_event_id
      direct = params[:event_id] ||
               params[:business_matching_event_id] ||
               params.dig(:voucher, :event_id)
      return direct.to_i if direct.present? && direct.to_s.match?(/\A\d+\z/)

      slug = params[:event_slug] || params[:slug]
      if slug.present?
        event = Event.with_deleted.friendly.find_by(slug: slug) ||
                (slug.to_s.match?(/\A\d+\z/) ? Event.with_deleted.find_by(id: slug) : nil)
        return event&.id
      end

      # /v1/scan/:public_id/check_in — resolve the event via the scanned record
      # so kiosks/scanners using an event-scoped API key still work for the
      # event they're scoped to.
      if params[:public_id].present?
        record = Ticket.find_by(public_id: params[:public_id]) ||
                 Visitor.find_by(public_id: params[:public_id])
        return record&.event_id
      end

      nil
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
