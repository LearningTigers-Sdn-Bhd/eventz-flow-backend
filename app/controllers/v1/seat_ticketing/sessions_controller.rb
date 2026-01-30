module V1
  module SeatTicketing
    class SessionsController < ApplicationController
      before_action :set_session, only: [:show, :update, :destroy, :restore, :force_delete]

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
        render json: @session
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

      private

      def set_session
         if action_name.in?(['restore', 'force_delete'])
            @session = EventSeatSession.with_deleted.find(params[:id])
         else
            @session = EventSeatSession.find(params[:id])
         end
         authorize @session
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
    end
  end
end
