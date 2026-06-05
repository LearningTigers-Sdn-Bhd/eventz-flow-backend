module V1
  module SeatTicketing
    class PublicSessionsController < ApplicationController
      include SeatTicketingContext
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def index
        return render json: { error: 'event_slug is required' }, status: :bad_request if params[:event_slug].blank?

        event = Event.friendly.find(params[:event_slug])
        return render json: { error: 'Event not found' }, status: :not_found unless event.use_seat_ticketing?

        sessions = EventSeatSession
          .where(event_id: event.id, status: :published)

        render json: sessions.map { |session| public_session_summary(session) }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Event not found' }, status: :not_found
      end

      def show
        identifier = params[:id]
        @session = EventSeatSession.includes(:event, event_seat_venues: :event_seat_sections)
          .find_by(id: identifier) ||
          EventSeatSession.includes(:event, event_seat_venues: :event_seat_sections)
          .find_by(slug: identifier) ||
          EventSeatSession.includes(:event, event_seat_venues: :event_seat_sections)
          .find_by(public_id: identifier)

        if @session&.published?
          return render json: { error: 'Session not found' }, status: :not_found unless @session.event.use_seat_ticketing?

          render json: diet_session_payload(@session)
        else
          render json: { error: 'Session not found' }, status: :not_found
        end
      end

      def section_seats
        # Find the section and ensure it belongs to a published session
        @section = EventSeatSection.find(params[:section_id])
        @session = @section.event_seat_venue.event_seat_session

        if @session&.published? && @session.event.use_seat_ticketing?
          render json: {
            section_id: @section.id,
            seats: @section.event_ticket_seats.as_json(
              methods: :status,
              include: :event_seat_group_assignment
            )
          }
        else
          render json: { error: 'Session not found or not published' }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Section not found' }, status: :not_found
      end

      def checkout
        identifier = params[:id]
        @session = EventSeatSession.find_by(id: identifier) ||
          EventSeatSession.find_by(slug: identifier) ||
          EventSeatSession.find_by(public_id: identifier)

        return render json: { error: 'Session not found' }, status: :not_found unless @session
        return render json: { error: 'Session not found' }, status: :not_found unless @session.event.use_seat_ticketing?
        return render json: { error: 'Session not published' }, status: :forbidden unless @session.published?

        service = ::SeatTicketing::CheckoutService.new(@session, params)
        if service.call
          render json: service.result
        else
          render json: { errors: service.errors }, status: :unprocessable_content
        end
      end

      private

      def public_session_summary(session)
        session.as_json.merge(archived: false)
      end

      def diet_session_payload(session)
        # Pre-fetch counts for all sections in this session to avoid N+1 and Ruby loops
        section_counts = EventTicketSeat
          .joins(event_seat_section: { event_seat_venue: :event_seat_session })
          .where(event_seat_sessions: { id: session.id })
          .group(:event_seat_section_id)
          .select(
            :event_seat_section_id,
            'COUNT(*) as total_count',
            'COUNT(CASE WHEN ticket_id IS NULL AND visitor_id IS NULL THEN 1 END) as available_count'
          ).index_by(&:event_seat_section_id)

        session.as_json(
          include: {
            event_seat_venues: {
              include: {
                event_seat_sections: {
                  include: {
                    event_seat_groups: {}
                  }
                }
              }
            }
          }
        ).tap do |json|
          json['event_seat_venues']&.each do |venue_json|
            venue = session.event_seat_venues.find { |v| v.id == venue_json['id'] }
            venue_json['image_url'] = venue_image_url(venue) if venue

            venue_json['event_seat_sections']&.each do |section_json|
              counts = section_counts[section_json['id']]
              counts_key = session.event.use_ticket ? :ticket_seat_counts : :visitor_seat_counts
              section_json[counts_key] = {
                total: counts&.total_count || 0,
                available: counts&.available_count || 0
              }
            end
          end
        end
      end
    end
  end
end
