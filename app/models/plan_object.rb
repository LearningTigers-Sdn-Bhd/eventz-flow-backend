class PlanObject < ApplicationRecord
  belongs_to :plan
  has_many :table_assignments, dependent: :destroy

  enum :object_type, { table: 0, wall: 1, door: 2, stage: 3, label: 4 }, prefix: true

  validates :x, presence: true
  validates :y, presence: true
  validates :width, numericality: { greater_than: 0 }, allow_nil: true
  validates :height, numericality: { greater_than: 0 }, allow_nil: true
  validates :capacity, numericality: { greater_than_or_equal_to: 0 }, if: :object_type_table?
end