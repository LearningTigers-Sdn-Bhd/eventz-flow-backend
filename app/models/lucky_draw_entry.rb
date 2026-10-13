class LuckyDrawEntry < ApplicationRecord
  belongs_to :lucky_draw_session
  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true
  belongs_to :scanned_by, class_name: 'User', optional: true

  validate :exactly_one_participant
  validate :participant_belongs_to_event

  private

  def exactly_one_participant
    return if ticket_id.present? ^ visitor_id.present?

    errors.add(:base, 'Exactly one of ticket_id or visitor_id must be present')
  end

  def participant_belongs_to_event
    return unless lucky_draw_session

    participant = ticket || visitor
    return if participant.nil? || participant.event_id == lucky_draw_session.event_id

    errors.add(:base, 'Participant must belong to the event')
  end
end
