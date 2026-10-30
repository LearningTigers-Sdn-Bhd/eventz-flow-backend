module V1
  module LuckyDraw
    class LuckyDrawEntriesController < ApplicationController
      before_action :set_event
      before_action :set_session

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/entries
      # Body: { public_id } - the QR value from the visitor's existing ticket,
      # or { participant_id } from search (staff only, exhibitors must hold the QR)
      def create
        authorize LuckyDrawEntry.new(lucky_draw_session: @session)
        return exhibitor_forbidden if params[:participant_id].present? && exhibitor?

        participant = find_participant
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

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/entries?page=1&per_page=20
      # One page of entries, newest first (pagy; the list can reach thousands)
      def index
        authorize LuckyDrawEntry.new(lucky_draw_session: @session)

        scope = @session.lucky_draw_entries.includes(:ticket, :visitor).order(created_at: :desc, id: :desc)
        pagy, entries = pagy(scope, limit: pagination_params[:per_page])
        success_response(data: entries.map { |e| format_entry(e) }, pagination: pagy_metadata(pagy))
      end

      # DELETE /v1/events/:event_id/lucky_draw/sessions/:session_id/entries/:id
      # Takes a scanned participant back out of the draw pool (wrong scan, or left early)
      def destroy
        entry = @session.lucky_draw_entries.find(params[:id])
        authorize entry
        entry.destroy!
        success_response(data: nil, message: 'Entry removed')
      end

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/entries/search?q=ali
      # Fallback when a QR will not scan: find people by name, phone or email.
      def search
        authorize LuckyDrawEntry.new(lucky_draw_session: @session), :index?
        # Exhibitors only reach their own leads (see participants); search spans the whole event
        return exhibitor_forbidden if exhibitor?

        query = params[:q].to_s.strip
        return success_response(data: [], message: 'Success') if query.length < 2

        ticket = @event.use_ticket
        columns = ticket ? %w[attendee_name attendee_phone attendee_email] : %w[full_name phone email]
        like = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        matches = (ticket ? Ticket : Visitor).where(event_id: @event.id)
                                             .where(columns.map { |c| "#{c} ILIKE :q" }.join(' OR '), q: like)
                                             .order(columns.first).limit(SEARCH_LIMIT).to_a
        key = ticket ? :ticket_id : :visitor_id
        entered = @session.lucky_draw_entries.where(key => matches.map(&:id)).pluck(key)

        data = matches.map do |p|
          # id, not public_id: the public_id is the ticket's QR credential
          { id: p.id, name: participant_name(p), contact: p.draw_contact,
            entered: entered.include?(p.id), ineligible_reason: ineligible_reason(p) }
        end
        success_response(data: data, message: 'Success')
      end

      private

      SEARCH_LIMIT = 10

      def participant_name(participant)
        participant.is_a?(Ticket) ? participant.attendee_name : participant.full_name
      end

      def set_event
        @event = Event.find_by!(id: params[:event_id])
      end

      def set_session
        @session = @event.lucky_draw_sessions.find(params[:session_id])
      end

      def find_participant
        scope = @event.use_ticket ? Ticket : Visitor
        return scope.find_by(id: params[:participant_id], event_id: @event.id) if params[:participant_id].present?

        scope.find_by(public_id: params[:public_id], event_id: @event.id)
      end

      def exhibitor?
        current_user.exhibitor_for?(@event)
      end

      def exhibitor_forbidden
        error_response(message: 'Not available for exhibitors. Scan the ticket QR instead.', status: :forbidden)
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
          name: participant_name(participant),
          contact: participant.draw_contact,
          entered_at: entry.created_at
        }
      end
    end
  end
end
