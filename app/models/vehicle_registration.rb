class VehicleRegistration < ApplicationRecord
  belongs_to :event
  belongs_to :registration_form
  belongs_to :base_ticket_type, class_name: 'TicketType'
  has_many :tickets, dependent: :nullify

  validates :plate, :normalized_plate, presence: true
  validates :normalized_plate, uniqueness: { scope: :event_id }
  validate :associations_belong_to_event

  def self.normalize_plate(value)
    value.to_s.upcase.gsub(/[^A-Z0-9]/, '')
  end

  def active_tickets
    tickets.where.not(status: %i[canceled refunded])
  end

  private

  def associations_belong_to_event
    return if event_id.blank?

    errors.add(:registration_form, 'must belong to the same event') if registration_form&.event_id != event_id
    errors.add(:base_ticket_type, 'must belong to the same event') if base_ticket_type&.event_id != event_id
  end
end
