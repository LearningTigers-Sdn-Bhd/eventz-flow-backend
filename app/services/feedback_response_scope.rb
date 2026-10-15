# frozen_string_literal: true

# Shared filters for the organizer's feedback views (summary, comments,
# non-responders, export), so every screen and file agrees on "what's in view".
class FeedbackResponseScope
  class InvalidFilter < StandardError; end

  # Tickets that could have answered: checked in and still valid.
  def self.eligible_tickets(event, ticket_type_id: nil)
    tickets = event.tickets.where(checked_in: true, waiting_list: false)
                   .where.not(status: %i[canceled refunded])
    tickets = tickets.where(ticket_type_id:) if ticket_type_id.present?
    tickets
  end

  # filters: { ticket_type_id:, from: 'YYYY-MM-DD', to: 'YYYY-MM-DD' } (all optional)
  def self.call(form, filters = {})
    filters = (filters || {}).to_h.symbolize_keys
    scope = form.feedback_responses

    if filters[:ticket_type_id].present?
      scope = scope.where(ticket_id: Ticket.where(ticket_type_id: filters[:ticket_type_id]).select(:id))
    end
    scope = scope.where(submitted_at: parse_date(filters[:from]).beginning_of_day..) if filters[:from].present?
    scope = scope.where(submitted_at: ..parse_date(filters[:to]).end_of_day) if filters[:to].present?
    scope
  end

  def self.parse_date(value)
    Time.zone.parse(Date.iso8601(value.to_s).to_s)
  rescue Date::Error
    raise InvalidFilter, "Invalid date: #{value}"
  end
  private_class_method :parse_date
end
