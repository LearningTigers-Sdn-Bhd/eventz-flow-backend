class InvalidParticipant < ApplicationRecord
  # --- Associations ---
  belongs_to :lucky_draw_session
  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true

  # --- Validations ---
  validates :lucky_draw_session_id, presence: true
  validate :exactly_one_participant
  validate :participant_belongs_to_event

  # --- Private Methods ---
  private

  def exactly_one_participant
    if ticket_id.blank? && visitor_id.blank?
      errors.add(:base, "Either ticket_id or visitor_id must be present")
    elsif ticket_id.present? && visitor_id.present?
      errors.add(:base, "Only one of ticket_id or visitor_id can be present")
    end
  end

  def participant_belongs_to_event
    return unless lucky_draw_session

    event_id = lucky_draw_session.event_id

    if ticket_id.present?
      unless Ticket.exists?(id: ticket_id, event_id: event_id)
        errors.add(:ticket_id, "must belong to the event")
      end
    elsif visitor_id.present?
      unless Visitor.exists?(id: visitor_id, event_id: event_id)
        errors.add(:visitor_id, "must belong to the event")
      end
    end
  end
end