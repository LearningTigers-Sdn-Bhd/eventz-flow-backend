module V1
  module LuckyDraw
    class LuckyDrawEntriesController < ApplicationController
      before_action :set_event
      before_action :set_session

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/entries
      # Body: { public_id } - the QR value from the visitor's existing ticket
      def create
        authorize LuckyDrawEntry.new(lucky_draw_session: @session)

        participant = find_participant(params[:public_id])
        return error_response(message: 'Record not found. Invalid QR code.', status: :not_found) unless participant

        if (reason = ineligible_reason(participant))
          return error_response(message: reason, status: :unprocessable_content)
        end

        key = participant.is_a?(Ticket) ? :ticket : :visitor
        entry = @session.lucky_draw_entries.build(key => participant, scanned_by: current_user)

        if entry.save
          success_response(data: format_entry(entry), message: 'Entered into lucky draw', status: :created)
        else
          error_response(message: entry.errors.full_messages.to_sentence, status: :unprocessable_content)
        end
      rescue ActiveRecord::RecordNotUnique
        error_response(message: 'Already entered into this lucky draw', status: :unprocessable_content)
      end

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/entries?limit=20
      # Latest entries (newest first) plus meta.total; never returns the full list.
      def index
        authorize LuckyDrawEntry.new(lucky_draw_session: @session)

        scope = @session.lucky_draw_entries
        entries = scope.includes(:ticket, :visitor).order(created_at: :desc, id: :desc).limit(index_limit)
        success_response(data: entries.map { |e| format_entry(e) }, message: 'Success', meta: { total: scope.count })
      end

      private

      def index_limit
        params.fetch(:limit, 20).to_i.clamp(1, 100)
      end

      def set_event
        @event = Event.find_by!(id: params[:event_id])
      end

      def set_session
        @session = @event.lucky_draw_sessions.find(params[:session_id])
      end

      def find_participant(public_id)
        scope = @event.use_ticket ? Ticket : Visitor
        scope.find_by(public_id: public_id, event_id: @event.id)
      end

      # Same payment rule as check-in, and refunded/canceled tickets never qualify
      def ineligible_reason(participant)
        return unless participant.is_a?(Ticket)
        return 'Ticket is refunded or canceled' if participant.refunded? || participant.canceled?

        'Ticket payment is not confirmed' unless participant.paid?
      end

      def format_entry(entry)
        participant = entry.ticket || entry.visitor
        {
          id: entry.id,
          participant_id: participant.id,
          name: participant.is_a?(Ticket) ? participant.attendee_name : participant.full_name,
          entered_at: entry.created_at
        }
      end
    end
  end
end
