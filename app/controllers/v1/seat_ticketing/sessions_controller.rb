module V1
  module SeatTicketing
    class SessionsController < ApplicationController
      include SeatTicketingContext
      before_action :set_session, only: [:show, :update, :bulk_update, :destroy, :restore, :force_delete, :duplicate]
      skip_before_action :authenticate_user!, only: [:public_index, :public_show]
      skip_before_action :require_verified_email!, only: [:public_index, :public_show]

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
        sessions = EventSeatSession.where(event_id: event.id, status: :published)
        render json: sessions.map { |session| session.as_json.merge(archived: false) }
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Event not found', status: :not_found)
      end

      def public_show
        identifier = params[:id]
        session = EventSeatSession.find_by(id: identifier) ||
          EventSeatSession.find_by(slug: identifier) ||
          EventSeatSession.find_by(public_id: identifier)

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
              :seat_row, :seat_column, :row_span, :col_span, :_destroy,
              event_ticket_seats_attributes: [
                :id, :name, :extra_price, :row_set, :col_set, :ticket_id, :_destroy
              ]
            ]
          ]
        )
      end
    end
  end
end
