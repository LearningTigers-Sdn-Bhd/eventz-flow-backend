class ExhibitorPackage < ApplicationRecord
  belongs_to :event
  belongs_to :exhibitor_booth_price
  has_many :exhibitor_kits, dependent: :restrict_with_error
  has_many :exhibitor_vouchers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :event_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quota, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :booth_price_must_belong_to_event

  # Guard for every path that accepts a package id alongside a booth price id.
  def matches_booth_price?(booth_price_id)
    exhibitor_booth_price_id == booth_price_id.to_i
  end

  private

  def booth_price_must_belong_to_event
    return if exhibitor_booth_price.blank?
    return if exhibitor_booth_price.event_id == event_id

    errors.add(:exhibitor_booth_price_id, 'must belong to the same event')
  end
end
