class GiftWinner < ApplicationRecord
  # --- Associations ---
  belongs_to :gift
  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true

  # --- Validations ---
  validates :gift_id, presence: true
  validates :drawn_at, presence: true
  validates :round, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :exactly_one_participant
  validate :participant_belongs_to_event
  validate :ticket_type_not_excluded, on: :create

  # --- Scopes ---
  scope :active, -> { where(voided_at: nil) }

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
    return unless gift&.lucky_draw_session&.event_id

    event_id = gift.lucky_draw_session.event_id

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

  def ticket_type_not_excluded
    return unless ticket && gift&.lucky_draw_session&.excludes_ticket?(ticket)

    errors.add(:ticket_id, "has a ticket type excluded from this draw")
  end
end
