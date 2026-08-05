# frozen_string_literal: true

module V1
  module BusinessMatching
    class PortalsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!
      before_action :authenticate_portal_participant!

      # GET /v1/business_matching/portal
      def show
        render json: portal_payload(@participant), status: :ok
      end

      # GET /v1/business_matching/portal/tags
      def tags
        event = @participant.event
        render json: {
          offering_tags: event.business_matching_offering_tags || [],
          interest_tags: event.business_matching_interest_tags || []
        }, status: :ok
      end

      # PUT /v1/business_matching/portal
      def update
        tag_params = params.permit(offering_tags: [], interest_tags: [])

        invalid_tags = disallowed_tags(@participant.event, tag_params)
        if invalid_tags.any?
          return render json: { errors: ["The following tags are not available for this event: #{invalid_tags.join(', ')}"] }, status: :unprocessable_entity
        end

        @participant.offering_tags = tag_params[:offering_tags] || []
        @participant.interest_tags = tag_params[:interest_tags] || []

        if @participant.save
          render json: {
            message: "Profile updated successfully",
            offering_tags: @participant.offering_tags,
            interest_tags: @participant.interest_tags
          }, status: :ok
        else
          render json: { errors: @participant.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /v1/business_matching/portal/matches
      def matches
        all_participants = BusinessMatchingParticipant
                             .where(event_id: @participant.event_id)
                             .where.not(id: @participant.id)
                             .includes(:registerable)

        # Calculate scores
        ranked = all_participants.map do |p|
          score = calculate_similarity_score(@participant, p)
          {
            participant: serialize_participant(p),
            match_score: (score * 100).round(1)
          }
        end

        # Sort by match score descending
        ranked.sort_by! { |item| -item[:match_score] }

        render json: ranked, status: :ok
      end

      # POST /v1/business_matching/portal/bookings
      def create_booking
        receiver = BusinessMatchingParticipant.find_by(id: params[:receiver_participant_id])
        return render json: { error: 'Receiver participant not found' }, status: :not_found unless receiver

        # Verify recipient availability slot
        session = BusinessMatchingSession.find_by(event_id: @participant.event_id)
        return render json: { error: 'No active matching session for this event' }, status: :not_found unless session

        booking = BusinessMatchingBooking.new(
          business_matching_session: session,
          requester_participant: @participant,
          receiver_participant: receiver,
          name: @participant.registerable.respond_to?(:full_name) ? @participant.registerable.full_name : "Participant",
          email: @participant.registerable.respond_to?(:email) ? @participant.registerable.email : "",
          phone: @participant.registerable.respond_to?(:phone) ? @participant.registerable.phone : "",
          booking_date: Date.parse(params[:date]),
          booking_time: params[:time],
          duration: session.slot_duration,
          status: "Approved",
          payment_status: "Pending"
        )

        if booking.save
          ActionCable.server.broadcast("business_matching_event_#{session.event_id}", { action: "bookings_updated" })
          render json: serialize_booking(booking), status: :created
        else
          render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /v1/business_matching/portal/bookings/:id/respond
      def respond_booking
        booking = BusinessMatchingBooking.find_by(id: params[:id])
        return render json: { error: 'Booking not found' }, status: :not_found unless booking

        # Ensure participant is the receiver
        return render json: { error: 'Unauthorized' }, status: :unauthorized unless booking.receiver_participant_id == @participant.id

        status = params[:response] == "accept" ? "Approved" : "Cancelled"
        if booking.update(status: status)
          ActionCable.server.broadcast("business_matching_event_#{booking.business_matching_session.event_id}", { action: "bookings_updated" })
          render json: serialize_booking(booking), status: :ok
        else
          render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # Participants may only select tags from the event's admin-curated
      # list, never create new ones.
      def disallowed_tags(event, tag_params)
        invalid = []
        if tag_params[:offering_tags].present?
          invalid += Array(tag_params[:offering_tags]) - (event.business_matching_offering_tags || [])
        end
        if tag_params[:interest_tags].present?
          invalid += Array(tag_params[:interest_tags]) - (event.business_matching_interest_tags || [])
        end
        invalid.uniq
      end

      def authenticate_portal_participant!
        token = params[:token] || request.headers['Authorization']&.split(' ')&.last
        @participant = BusinessMatchingParticipant.find_by(magic_token: token)
        
        unless @participant
          render json: { error: 'Invalid or missing magic token' }, status: :unauthorized
        end
      end

      def calculate_similarity_score(p1, p2)
        o1 = p1.offering_tags
        i1 = p1.interest_tags
        o2 = p2.offering_tags
        i2 = p2.interest_tags

        intersection = (o1 & i2).size + (i1 & o2).size
        union = (o1 + i1 + o2 + i2).uniq.size

        union.zero? ? 0.0 : (intersection.to_f / union.to_f)
      end

      def serialize_participant(p)
        {
          id: p.id.to_s,
          name: p.registerable.respond_to?(:full_name) ? p.registerable.full_name : "Exhibitor/Visitor",
          company: p.registerable.respond_to?(:company_name) ? p.registerable.company_name : "",
          role: p.registerable_type,
          offering_tags: p.offering_tags,
          interest_tags: p.interest_tags
        }
      end

      def serialize_booking(b)
        {
          id: b.id,
          date: b.booking_date.to_s,
          time: b.booking_time,
          status: b.status,
          requester: serialize_participant(b.requester_participant),
          receiver: serialize_participant(b.receiver_participant)
        }
      end

      def portal_payload(p)
        sent = p.sent_bookings.includes(:receiver_participant).map { |b| serialize_booking(b) }
        received = p.received_bookings.includes(:requester_participant).map { |b| serialize_booking(b) }
        
        {
          participant: serialize_participant(p),
          offering_tags: p.offering_tags,
          interest_tags: p.interest_tags,
          bookings: sent + received
        }
      end
    end
  end
end
