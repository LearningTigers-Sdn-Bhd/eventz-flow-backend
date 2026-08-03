# frozen_string_literal: true

module V1
  module BusinessMatching
    class SessionsController < ApplicationController
      # POST /v1/business_matching/sessions
      def create
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :update?

        session = BusinessMatchingSession.new(session_params)
        session.event = event

        if session.save
          # Create a default availability for each event day
          start_date = event.start_date&.to_date || Time.zone.today
          end_date = event.end_date&.to_date || start_date
          (start_date..end_date).each do |day|
            BusinessMatchingAvailability.create!(
              business_matching_session: session,
              day: day,
              start_time: session.start_time,
              end_time: session.end_time
            )
          end

          ActionCable.server.broadcast("business_matching_event_#{event.id}", { action: "sessions_updated" })
          render json: {
            id: session.id.to_s,
            event_id: event.id.to_s,
            title: session.title,
            duration: session.slot_duration,
            location: session.location,
            admin_email: session.admin_email,
            admin_wa_number: session.admin_wa_number,
            start_time: session.start_time,
            end_time: session.end_time
          }, status: :created
        else
          render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT/PATCH /v1/business_matching/sessions/:id
      def update
        session = BusinessMatchingSession.find_by(id: params[:id])
        return render json: { error: 'Session not found' }, status: :not_found unless session

        authorize session.event, :update?

        if session.update(session_params)
          ActionCable.server.broadcast("business_matching_event_#{session.event_id}", { action: "sessions_updated" })
          render json: {
            id: session.id.to_s,
            event_id: session.event_id.to_s,
            title: session.title,
            duration: session.slot_duration,
            location: session.location,
            admin_email: session.admin_email,
            admin_wa_number: session.admin_wa_number,
            start_time: session.start_time,
            end_time: session.end_time
          }, status: :ok
        else
          render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /v1/business_matching/sessions/:id
      def destroy
        session = BusinessMatchingSession.find_by(id: params[:id])
        return render json: { error: 'Session not found' }, status: :not_found unless session

        event = session.event
        authorize event, :update?

        if session.destroy
          ActionCable.server.broadcast("business_matching_event_#{event.id}", { action: "sessions_updated" })
          render json: { message: 'Session deleted successfully' }, status: :ok
        else
          render json: { error: session.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end

      private

      def session_params
        params.require(:session).permit(:title, :slot_duration, :location, :admin_email, :admin_wa_number, :start_time, :end_time, :is_active)
      end
    end
  end
end
