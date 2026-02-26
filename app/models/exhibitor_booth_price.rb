class ExhibitorBoothPrice < ApplicationRecord
  belongs_to :event
  has_many :exhibitor_kits, dependent: :nullify

  validates :booth_type, presence: true
  validates :label, presence: true, uniqueness: { scope: [:event_id, :booth_type] }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
