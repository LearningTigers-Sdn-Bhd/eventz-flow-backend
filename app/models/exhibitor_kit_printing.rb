class ExhibitorKitPrinting < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :printing_service
  belongs_to :exhibitor_kit_payment, optional: true

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :agreed_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :printing_service_must_be_active_and_linked_to_event

  private

  def printing_service_must_be_active_and_linked_to_event
    return unless printing_service.present? && exhibitor_kit.present? && exhibitor_kit.event.present?

    # Check if the printing_service is active
    unless printing_service.status == 'active'
      errors.add(:printing_service, "must be active to be added to the kit")
    end

    # Check if the printing_service is linked to the exhibitor_kit's event
    # Find the corresponding EventPrintingService
    event_printing_service = exhibitor_kit.event.event_printing_services.find_by(printing_service_id: printing_service.id)
    unless event_printing_service.present?
      errors.add(:printing_service, "must be linked to the exhibitor kit's event")
    end
  end
end
