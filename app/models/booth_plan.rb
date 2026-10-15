class BoothPlan < ApplicationRecord
  belongs_to :event, inverse_of: :booth_plans
  has_one_attached :image

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
