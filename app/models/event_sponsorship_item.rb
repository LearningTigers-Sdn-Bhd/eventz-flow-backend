class EventSponsorshipItem < ApplicationRecord
  # --- Associations ---
  belongs_to :event_sponsorship
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  # --- Enums ---
  enum :item_type, { monetary: 0, in_kind: 1 }

  # --- Validations ---
  validates :title, presence: true

  # --- Callbacks ---
  after_commit :update_sponsorship_totals

  private

  def update_sponsorship_totals
    event_sponsorship.update_payment_totals!
  end
end
