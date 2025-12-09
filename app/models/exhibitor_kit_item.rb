class ExhibitorKitItem < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :rentable_item
  belongs_to :exhibitor_kit_payment, optional: true

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :agreed_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :rentable_item_must_be_active_and_linked_to_event

  private

  def rentable_item_must_be_active_and_linked_to_event
    return unless rentable_item.present? && exhibitor_kit.present? && exhibitor_kit.event.present?

    # Check if the rentable_item is active
    unless rentable_item.status == 'active'
      errors.add(:rentable_item, "must be active to be added to the kit")
    end

    # Check if the rentable_item is linked to the exhibitor_kit's event
    # Find the corresponding EventRentableItem
    event_rentable_item = exhibitor_kit.event.event_rentable_items.find_by(rentable_item_id: rentable_item.id)
    unless event_rentable_item.present?
      errors.add(:rentable_item, "must be linked to the exhibitor kit's event")
    end
  end
end
