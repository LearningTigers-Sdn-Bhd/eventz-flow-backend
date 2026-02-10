module V1
  module SeatTicketing
    class SessionsController < ApplicationController
      include SeatTicketingContext
      before_action :set_session, only: [:show, :update, :bulk_update, :destroy, :restore, :force_delete, :duplicate, :checkout]
      skip_before_action :authenticate_user!, only: [:public_index, :public_show, :checkout]
      skip_before_action :require_verified_email!, only: [:public_index, :public_show, :checkout]

      def index
        return render json: { error: 'event_id is required' }, status: :bad_request if params[:event_id].blank?

        @sessions = policy_scope(EventSeatSession).where(event_id: params[:event_id])
        
        if params[:archived] == 'true'
          @sessions = @sessions.only_deleted
        elsif params[:full] == 'true'
          @sessions = @sessions.with_deleted
        end

        render json: @sessions.map { |session| session.as_json.merge(archived: session.deleted_at.present?) }
      end

      def show
        render json: seat_session_with_details(@session)
      end

      def public_index
        return error_response(message: 'event_slug is required', status: :bad_request) if params[:event_slug].blank?

        event = Event.friendly.find(params[:event_slug])
        sessions = EventSeatSession
          .includes(event_seat_venues: { event_seat_sections: :event_ticket_seats })
          .where(event_id: event.id, status: :published)

        render json: sessions.map { |session| public_session_payload(session) }
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Event not found', status: :not_found)
      end

      def public_show
        identifier = params[:id]
        session = EventSeatSession.includes(:event, event_seat_venues: { event_seat_sections: :event_ticket_seats }).find_by(id: identifier) ||
          EventSeatSession.includes(:event, event_seat_venues: { event_seat_sections: :event_ticket_seats }).find_by(slug: identifier) ||
          EventSeatSession.includes(:event, event_seat_venues: { event_seat_sections: :event_ticket_seats }).find_by(public_id: identifier)

        if session&.published?
          render json: seat_session_with_details(session)
        else
          error_response(message: 'Session not found', status: :not_found)
        end
      end

      def create
        @session = EventSeatSession.new(session_params)
        authorize @session

        if @session.save
          render json: @session, status: :created
        else
          render json: { errors: @session.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @session.update(session_params)
          render json: @session
        else
           render json: { errors: @session.errors.full_messages }, status: :unprocessable_content
        end
      end

      def bulk_update
        authorize @session, :update?
        
        if @session.update(bulk_update_params)
          render json: seat_session_with_details(@session)
        else
          render json: { errors: @session.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @session.archive
        head :no_content
      end

      def restore
         @session.restore
         render json: @session
      end

      def force_delete
        @session.destroy
        head :no_content
      end

      def duplicate
        authorize @session, :create?

        new_session = @session.deep_duplicate!
        render json: new_session, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      def checkout
        # Skip authorization for public checkout
        return error_response(message: 'Session not published', status: :forbidden) unless @session.published?

        seat_ids = params[:seat_ids]
        visitor_params = params.require(:visitor).permit(:full_name, :email, :phone)
        ticket_type_id = params[:ticket_type_id]
        checkout_session_uuid = params[:checkout_session_uuid].presence
        event = @session.event

        if checkout_session_uuid.blank?
          return error_response(message: 'checkout_session_uuid is required', status: :bad_request)
        end

        checkout_session = EventSeatCheckoutSession.find_by(id: checkout_session_uuid)
        if checkout_session.nil? || checkout_session.event_seat_session_id != @session.id
          return error_response(message: 'Checkout session not found', status: :forbidden)
        end

        if checkout_session.expired?
          return error_response(message: 'Checkout session expired', status: :conflict)
        end

        if seat_ids.blank?
          return error_response(message: 'No seats selected', status: :bad_request)
        end

        seats = EventTicketSeat
          .joins(event_seat_section: { event_seat_venue: :event_seat_session })
          .where(id: seat_ids, event_seat_sessions: { id: @session.id })
        if seats.count != seat_ids.count
          return error_response(message: 'Some seats were not found', status: :not_found)
        end

        # Validate availability
        invalid_seats = seats.reject do |seat|
          seat.available? || (seat.locked? && seat.locked_by_session_id == checkout_session_uuid)
        end
        if invalid_seats.any?
          return error_response(message: "Some seats are no longer available: #{invalid_seats.map(&:name).join(', ')}", status: :conflict)
        end

        if event.use_ticket?
          ticket_type_id ||= event.ticket_types.first&.id
          if ticket_type_id.blank?
            return error_response(message: 'ticket_type_id is required', status: :unprocessable_content)
          end
        end

        ActiveRecord::Base.transaction do
          # 1. Create/Find Visitor (Always created for tracking, regardless of ticket mode)
          @visitor = Visitor.find_or_create_by!(
            event_id: event.id,
            email: visitor_params[:email]
          ) do |v|
            v.full_name = visitor_params[:full_name]
            v.phone = visitor_params[:phone]
          end

          # 2. Conditionally Create Ticket
          if event.use_ticket?
            @ticket = Ticket.create!(
              event_id: event.id,
              ticket_type_id: ticket_type_id,
              attendee_name: visitor_params[:full_name],
              attendee_email: visitor_params[:email],
              attendee_phone: visitor_params[:phone],
              payment_status: :paid,
              status: :purchased
            )
          end

          # 3. Update Seats
          seats.each do |seat|
            seat.update!(
              ticket_id: @ticket&.id,
              visitor_id: @visitor.id,
              locked_by_session_id: nil
            )
          end
        end

        checkout_session.destroy

        render json: {
          success: true,
          ticket: @ticket ? @ticket.as_json(include: :ticket_type) : nil,
          visitor: @visitor
        }
      rescue => e
        error_response(message: e.message, status: :unprocessable_content)
      end

      private
      def set_session
         load_seat_session(
           param_key: :id,
           include_deleted: action_name.in?(['restore', 'force_delete'])
         )
      end

      def session_params
        params.require(:session).permit(
          :event_id,
          :name,
          :status,
          :location,
          :start_datetime,
          :end_datetime
        )
      end

      def bulk_update_params
        params.require(:session).permit(
          :name, :status, :location, :start_datetime, :end_datetime,
          event_seat_venues_attributes: [
            :id, :name, :total_row, :total_column, :image, :aspect_ratio, :_destroy,
            event_seat_sections_attributes: [
              :id, :name, :price, :start_row, :start_column, 
              :seat_row, :seat_column, :row_span, :col_span, :rotation, :color, :_destroy,
              event_ticket_seats_attributes: [
                :id, :name, :extra_price, :row_set, :col_set, :ticket_id, :_destroy,
                event_seat_group_assignment_attributes: [:id, :event_seat_group_id, :_destroy]
              ],
              event_seat_groups_attributes: [
                :id, :name, :extra_price, :color, :_destroy,
                event_seat_group_assignments_attributes: [:id, :event_ticket_seat_id, :_destroy]
              ]
            ]
          ]
        )
      end

      def public_session_payload(session)
        session.as_json.merge(
          archived: false,
          event_seat_venues: session.event_seat_venues.map do |venue|
            {
              id: venue.id,
              event_seat_sections: venue.event_seat_sections.map do |section|
                seats = section.event_ticket_seats
                counts_key = session.event.use_ticket ? :ticket_seat_counts : :visitor_seat_counts
                {
                  id: section.id,
                  name: section.name,
                  price: section.price,
                  rotation: section.rotation,
                  counts_key => {
                    total: seats.count,
                    available: seats.count { |seat| seat.ticket_id.nil? && seat.visitor_id.nil? }
                  }
                }
              end
            }
          end
        )
      end
    end
  end
end
