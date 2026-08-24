# frozen_string_literal: true

module V1
  module BusinessMatching
    class SessionsController < ApplicationController
      # POST /v1/business_matching/sessions
      def create
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :manage_business_matching_sessions?

        session = BusinessMatchingSession.new(session_params)
        session.event = event

        if session.save
          ensure_default_availabilities(session)
          merge_event_tags(event)

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
            end_time: session.end_time,
            start_date: session.start_date,
            end_date: session.end_date,
            tags_editable: session.tags_editable,
            hours_editable: session.hours_editable,
            offering_tags: event.business_matching_offering_tags,
            interest_tags: event.business_matching_interest_tags
          }, status: :created
        else
          render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT/PATCH /v1/business_matching/sessions/:id
      def update
        session = BusinessMatchingSession.find_by(id: params[:id])
        return render json: { error: 'Session not found' }, status: :not_found unless session

        authorize session, :update?

        permitted_params = session_params
        # Session dates and the tags_editable toggle are admin-controlled — a
        # host editing their own session may never touch them, regardless of
        # what the request sends.
        permitted_params = permitted_params.except(:start_date, :end_date, :tags_editable, :hours_editable) unless EventPolicy.new(current_user, session.event).manage_business_matching_sessions?

        if session.update(permitted_params)
          ensure_default_availabilities(session)

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
            end_time: session.end_time,
            start_date: session.start_date,
            end_date: session.end_date,
            tags_editable: session.tags_editable,
            hours_editable: session.hours_editable
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
        authorize event, :manage_business_matching_sessions?

        if session.destroy
          ActionCable.server.broadcast("business_matching_event_#{event.id}", { action: "sessions_updated" })
          render json: { message: 'Session deleted successfully' }, status: :ok
        else
          render json: { error: session.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end

      private

      # Backfills a default availability row for every day in the session's
      # date range that doesn't already have one — additive only, existing
      # rows are never touched or removed even if the range is edited later.
      #
      # Only the session's single "effective" bucket (see
      # BusinessMatchingSession#effective_host_user_id) is extended, so this
      # never creates a second parallel set of rows for the same days.
      def ensure_default_availabilities(session)
        return unless session.start_date && session.end_date

        host_user_id = session.effective_host_user_id
        existing_days = BusinessMatchingAvailability.where(
          business_matching_session_id: session.id, host_user_id: host_user_id
        ).pluck(:day)

        default_blocks = session.event.business_matching_default_hours.presence ||
                          [{ 'start_time' => session.start_time, 'end_time' => session.end_time }]

        (session.start_date..session.end_date).each do |day|
          next if existing_days.include?(day)

          default_blocks.each do |block|
            BusinessMatchingAvailability.create!(
              business_matching_session: session,
              host_user_id: host_user_id,
              day: day,
              start_time: block['start_time'] || block[:start_time],
              end_time: block['end_time'] || block[:end_time]
            )
          end
        end
      end

      def session_params
        params.require(:session).permit(
          :title, :slot_duration, :location, :admin_email, :admin_wa_number,
          :start_time, :end_time, :is_active, :start_date, :end_date, :tags_editable, :hours_editable
        )
      end

      # Tags are event-scoped, not session-scoped, so a new session only adds
      # to the event's existing offering/interest tag lists — it never
      # removes or overwrites tags another session may already rely on.
      def merge_event_tags(event)
        tag_params = params.require(:session).permit(offering_tags: [], interest_tags: [])
        return unless tag_params.key?(:offering_tags) || tag_params.key?(:interest_tags)

        update_attrs = {}
        if tag_params.key?(:offering_tags)
          update_attrs[:business_matching_offering_tags] =
            sanitize_tags(event.business_matching_offering_tags + tag_params[:offering_tags])
        end
        if tag_params.key?(:interest_tags)
          update_attrs[:business_matching_interest_tags] =
            sanitize_tags(event.business_matching_interest_tags + tag_params[:interest_tags])
        end

        event.update!(update_attrs)
      end

      def sanitize_tags(tags)
        Array(tags).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      end
    end
  end
end
