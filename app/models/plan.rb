class Plan < ApplicationRecord
  belongs_to :event
  has_many :plan_objects, dependent: :destroy
  has_many :table_assignments, through: :plan_objects
  has_many :event_seating_groups, dependent: :destroy
  has_one_attached :background_image, dependent: :purge_later
  
  has_secure_token :share_token

  validates :name, presence: true
  validates :canvas_width, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :canvas_height, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :pixels_per_unit, numericality: { greater_than: 0 }, allow_nil: true
end
