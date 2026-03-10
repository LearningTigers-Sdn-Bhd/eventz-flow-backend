# frozen_string_literal: true

module V1
  module Public
    class RsvpController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      # GET /v1/public/events/:slug/rsvp/:public_id
      def show
        event = Event.friendly.find(params[:slug])

        unless event.use_wedding?
          return render json: { error: 'RSVP is only available for wedding events' }, status: :not_found
        end

        visitor = event.visitors.primary_invitees.find_by!(public_id: params[:public_id])

        render json: {
          visitor: {
            full_name: visitor.full_name,
            public_id: visitor.public_id,
            rsvp_status: visitor.rsvp_status,
            rsvp_responded_at: visitor.rsvp_responded_at&.iso8601,
            companions: visitor.companions.map do |c|
              {
                id: c.id,
                full_name: c.full_name,
                phone: c.phone,
                email: c.email
              }
            end
          },
          event: {
            title: event.title,
            start_date: event.start_date&.iso8601,
            end_date: event.end_date&.iso8601,
            extra_guest_limit: event.extra_guest_limit
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Invitation not found' }, status: :not_found
      end

      # POST /v1/public/events/:slug/rsvp/:public_id/respond
      def respond_rsvp
        event = Event.friendly.find(params[:slug])

        unless event.use_wedding?
          return render json: { error: 'RSVP is only available for wedding events' }, status: :not_found
        end

        visitor = event.visitors.find_by!(public_id: params[:public_id])

        # Only primary invitees can respond
        if visitor.added_by_id.present?
          return render json: { error: 'Only primary invitees can respond to RSVP' }, status: :forbidden
        end

        rsvp_status = params[:rsvp_status]

        unless %w[attending declined].include?(rsvp_status)
          return render json: { error: 'Invalid RSVP status. Must be attending or declined.' },
                        status: :unprocessable_content
        end

        companions_data = Array(params[:companions])

        if rsvp_status == 'attending' && event.extra_guest_limit.present? && companions_data.length > event.extra_guest_limit
          return render json: {
            error: "You can bring a maximum of #{event.extra_guest_limit} additional guests"
          }, status: :unprocessable_content
        end

        ActiveRecord::Base.transaction do
          # Update primary visitor's RSVP status
          visitor.update!(
            rsvp_status: rsvp_status,
            rsvp_responded_at: Time.current
          )

          # Handle companions
          if rsvp_status == 'attending'
            # Remove old companions (for re-responses)
            visitor.companions.destroy_all

            # Create new companions
            companions_data.each do |companion|
              companion_custom_fields = {}
              wedding_side = visitor.custom_fields_data.to_h['wedding_side']
              companion_custom_fields['wedding_side'] = wedding_side if wedding_side.present?

              event.visitors.create!(
                full_name: companion[:full_name],
                phone: companion[:phone],
                email: companion[:email],
                custom_fields_data: companion_custom_fields,
                added_by_id: visitor.id,
                rsvp_status: :attending
              )
            end
          elsif rsvp_status == 'declined'
            # Remove companions if declining
            visitor.companions.destroy_all
          end
        end

        visitor.reload

        render json: {
          visitor: {
            full_name: visitor.full_name,
            public_id: visitor.public_id,
            rsvp_status: visitor.rsvp_status,
            rsvp_responded_at: visitor.rsvp_responded_at&.iso8601,
            companions: visitor.companions.reload.map do |c|
              {
                id: c.id,
                full_name: c.full_name,
                phone: c.phone,
                email: c.email
              }
            end
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Invitation not found' }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_content
      end
    end
  end
end
