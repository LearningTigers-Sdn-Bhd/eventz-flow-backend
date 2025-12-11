# app/controllers/v1/vendor_invitations_controller.rb
module V1
  class VendorInvitationsController < ApplicationController
    skip_before_action :authenticate_user!, only: [:verify]
    before_action :set_event

    # POST /v1/events/:event_id/vendor_invitations/generate_link
    def generate_link
      authorize @event, :update?

      organizer_id = if current_user.role == 'org_owner' && params[:organizer_id].present?
        params[:organizer_id]
      else
        current_user.id
      end

      payload = { event_id: @event.id, organizer_id: organizer_id, exp: 7.days.from_now.to_i }

      # Add group_id to the payload if provided
      if params[:group_id].present?
        group = Group.find_by(id: params[:group_id])
        if group
          payload[:group_id] = group.id
        end
      end

      token = Rails.application.message_verifier(:vendor_invite).generate(payload)

      invite_url = "#{ENV.fetch('REDIRECT_BASE_URL', 'http://localhost:3001')}/vendor-signup?token=#{token}"

      success_response(
        data: {
          invite_url: invite_url,
          token: token,
          expires_at: Time.at(payload[:exp]).iso8601,
          event: {
            id: @event.id,
            title: @event.title
          },
          group_id: payload[:group_id],
          organizer_id: organizer_id
        },
        message: 'Invitation link generated successfully'
      )
    end

    # GET /v1/events/:event_id/vendor_invitations/verify
    def verify
      token = params[:token]

      if token.blank?
        return error_response(
          message: 'Token is required',
          errors: [{ field: 'token', message: 'Invitation token is required' }],
          status: :unprocessable_content
        )
      end

      begin
        payload = Rails.application.message_verifier(:vendor_invite).verify(token)
        payload = payload.with_indifferent_access if payload.is_a?(Hash)
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        return error_response(
          message: 'Invalid invitation link',
          errors: [{ field: 'token', message: 'Invalid or malformed invitation token' }],
          status: :unauthorized
        )
      end

      exp = payload[:exp] || payload['exp']
      event_id = payload[:event_id] || payload['event_id']
      group_id = payload[:group_id] || payload['group_id']

      if exp.nil? || exp < Time.current.to_i
        return error_response(
          message: 'Invitation link expired',
          errors: [{ field: 'token', message: 'This invitation link has expired' }],
          status: :gone
        )
      end

      event = Event.find_by(id: event_id)
      unless event
        return error_response(
          message: 'Event not found',
          errors: [{ field: 'event', message: 'The event for this invitation no longer exists' }],
          status: :not_found
        )
      end

      organizer_id = payload[:organizer_id] || payload['organizer_id']

      # Get group info if group_id present
      group_data = nil
      if group_id.present?
        group = Group.find_by(id: group_id)
        group_data = { id: group.id, name: group.name } if group
      end

      # Check if authenticated vendor is already assigned to this event
      is_assigned = false
      is_authenticated = false
      if request.headers['Authorization'].present?
        begin
          auth_token = request.headers['Authorization'].split(' ').last
          decoded = JwtService.decode(auth_token)
          user = User.find_by(id: decoded[:user_id], jti: decoded[:jti])
          if user&.role == 'vendor'
            is_authenticated = true
            is_assigned = EventVendor.exists?(event_id: event.id, vendor_id: user.id)
          end
        rescue StandardError
          # Ignore auth errors - user is not authenticated
        end
      end

      success_response(
        data: {
          valid: true,
          expires_at: Time.at(exp).iso8601,
          organizer_id: organizer_id,
          is_authenticated: is_authenticated,
          is_assigned: is_assigned,
          vendor_type: event.use_ticket? ? 'Exhibitor' : 'Merchant',
          use_exhibitor_kit: event.use_exhibitor_kit?,
          event: {
            id: event.id,
            title: event.title,
            description: event.description,
            start_date: event.start_date&.iso8601,
            end_date: event.end_date&.iso8601
          },
          group: group_data
        },
        message: 'Token is valid'
      )
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    rescue ActiveRecord::RecordNotFound
      error_response(message: 'Event not found', status: :not_found)
    end
  end
end
