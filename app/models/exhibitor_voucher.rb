class ExhibitorVoucher < ApplicationRecord
  belongs_to :event
  belongs_to :exhibitor_booth_price, optional: true
  belongs_to :exhibitor_package, optional: true
  belongs_to :redeemed_by_exhibitor_kit, class_name: 'ExhibitorKit', optional: true

  enum :discount_type, { percentage_off: 0, fixed_amount_off: 1, flat_price: 2 }
  enum :status, { active: 0, redeemed: 1 }

  validates :code, presence: true, uniqueness: true
  validates :discount_value, numericality: { greater_than: 0 }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: :percentage_off?
  validate :booth_price_must_belong_to_event
  validate :package_must_match_booth_price_scope

  def self.generate_code
    loop do
      candidate = SecureRandom.alphanumeric(8).upcase
      break candidate unless exists?(code: candidate)
    end
  end

  def matches_selection?(booth_price:, package:)
    return false unless booth_price
    return false if exhibitor_booth_price_id.present? && exhibitor_booth_price_id != booth_price.id
    return false if exhibitor_package_id.present? && exhibitor_package_id != package&.id

    true
  end

  private

  def booth_price_must_belong_to_event
    return if exhibitor_booth_price.blank?
    return if exhibitor_booth_price.event_id == event_id

    errors.add(:exhibitor_booth_price_id, 'must belong to the same event')
  end

  def package_must_match_booth_price_scope
    return if exhibitor_package.blank?
    return if exhibitor_booth_price.present? &&
              exhibitor_package.exhibitor_booth_price_id == exhibitor_booth_price_id

    errors.add(:exhibitor_package_id, 'must match the scoped booth price')
  end
end
