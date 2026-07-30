module V1
  module Public
    class ExhibitorBookingsController < ApplicationController
      before_action :authenticate_public_exhibitor!
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def index
        authorize ExhibitorKit, policy_class: PublicExhibitorBookingPolicy
        scope = policy_scope(ExhibitorKit, policy_scope_class: PublicExhibitorBookingPolicy::Scope)
          .includes(:exhibitor_booth_price).order(created_at: :desc, id: :desc)
        per_page = pagination_params[:per_page] || 5
        @pagy, bookings = pagy(scope, limit: per_page)
        render json: { success: true, data: bookings.map { |kit| PublicExhibitorBookingSerializer.summary(kit) },
          meta: { can_register_another: true }, pagination: pagy_metadata(@pagy) }
      end

      def show
        kit = owned_scope.includes(:exhibitor_booth_price).find_by!(public_id: params[:public_id])
        authorize kit, policy_class: PublicExhibitorBookingPolicy
        render json: { success: true, data: PublicExhibitorBookingSerializer.detail(kit) }
      end

      def booth_number_availability
        authorize ExhibitorKit, :create?, policy_class: PublicExhibitorBookingPolicy
        booth_number = params[:booth_number].to_s.strip
        assigned = PublicExhibitorBookingService.new(event: @event, access: @public_access)
          .booth_number_assigned?(booth_number)
        message = assigned ? "Booth number #{booth_number} is already assigned" : nil
        render json: { success: true, data: { available: !assigned, message: message }.compact }
      end

      def create
        authorize ExhibitorKit, policy_class: PublicExhibitorBookingPolicy
        result = PublicExhibitorBookingService.call(event: @event, access: @public_access,
          idempotency_key: request.headers['Idempotency-Key'], attributes: create_booking_params,
          new_registration: @new_registration)
        session_token = if @new_registration
          PublicExhibitorAccessSession.issue_session!(event: @event, email: @public_access.normalized_email).last
        end
        render json: { success: true, data: PublicExhibitorBookingSerializer.detail(result.kit),
          meta: { idempotent_replay: result.idempotent_replay, session_token: session_token }.compact },
          status: result.idempotent_replay ? :ok : :created
      rescue ArgumentError
        render_booking_error('idempotency_key_required', 'Idempotency-Key is required', :bad_request)
      rescue PublicExhibitorBookingService::IdempotencyConflict
        render_booking_error('idempotency_key_reused', 'Idempotency-Key was already used for another booking', :conflict)
      rescue PublicExhibitorBookingService::SoldOut
        render_booking_error('booth_sold_out', 'Selected booth package is sold out', :conflict)
      rescue PublicExhibitorBookingService::DuplicateBoothNumber => e
        render_booking_error('duplicate_booth_number', e.message, :conflict)
      rescue PublicExhibitorBookingService::AgreementRequired
        render_booking_error('agreement_required', 'Participation and indemnity agreement must be accepted', :unprocessable_content)
      rescue PublicExhibitorBookingService::EmailRequiresAccess
        render_booking_error('email_requires_access', 'Account now exists. Request a secure access link.', :conflict)
      rescue ActiveRecord::RecordInvalid
        render_booking_error('booking_invalid', 'Booking details are invalid', :unprocessable_content)
      rescue ExhibitorIcCopyAttacher::Error
        render_booking_error('ic_copy_invalid', 'IC copy upload is invalid or unavailable', :unprocessable_content)
      rescue ActiveRecord::RecordNotFound
        render_booking_error('booth_package_not_found', 'Booth package not found', :not_found)
      end

      def update
        expected_lock_version = request.headers['If-Match'].to_s
        unless expected_lock_version.match?(/\A\d+\z/)
          return render_booking_error('if_match_required', 'A valid If-Match header is required', :precondition_required)
        end

        kit = owned_scope.find_by!(public_id: params[:public_id])
        authorize kit, policy_class: PublicExhibitorBookingPolicy
        updated = PublicExhibitorBookingService.new(event: @event, access: @public_access).update(
          kit: kit, expected_lock_version: expected_lock_version, attributes: update_booking_params
        )
        render json: { success: true, data: PublicExhibitorBookingSerializer.detail(updated) }
      rescue PublicExhibitorBookingService::StaleBooking
        render_booking_error('stale_booking', 'Booking was changed; reload and retry', :precondition_failed)
      rescue PublicExhibitorBookingService::ImmutableBooking
        render_booking_error('booking_immutable', 'Paid or inactive booking cannot be changed', :forbidden)
      rescue PublicExhibitorBookingService::SoldOut
        render_booking_error('booth_sold_out', 'Selected booth package is sold out', :conflict)
      rescue ActiveRecord::RecordInvalid
        render_booking_error('booking_invalid', 'Booking details are invalid', :unprocessable_content)
      end

      private

      def pundit_user
        @public_access
      end

      def authenticate_public_exhibitor!
        @event = Event.friendly.find(params[:event_slug])
        token = request.authorization.to_s.delete_prefix('Bearer ').presence
        @public_access = PublicExhibitorAccessSession.authenticate(event: @event, token: token)
        if @public_access.nil? && %w[create booth_number_availability].include?(action_name)
          @public_access = PublicExhibitorRegistrationToken.verify(
            token: request.headers['X-New-Registration-Token'], event: @event
          )
          @new_registration = @public_access.present?
        end
        raise CustomError::Unauthorized, 'Invalid or expired exhibitor session' unless @public_access
      end

      def owned_scope
        policy_scope(ExhibitorKit, policy_scope_class: PublicExhibitorBookingPolicy::Scope)
      end

      def create_booking_params
        params.permit(:exhibitor_booth_price_id, :company_name, :company_address, :name_on_fascia,
          :pic_full_name, :pic_position, :pic_contact_number, :country, :booth_number,
          :booth_quantity, :payment_option, :ic_copy_signed_id, :source_booking_public_id,
          :reuse_ic_copy, :indemnity_signed, custom_fields_data: {})
      end

      def update_booking_params
        params.permit(:exhibitor_booth_price_id, :company_name, :company_address, :name_on_fascia,
          :pic_full_name, :pic_position, :pic_contact_number, :country, :booth_number)
      end

      def render_booking_error(code, message, status)
        render json: { success: false, code: code, message: message }, status: status
      end
    end
  end
end
