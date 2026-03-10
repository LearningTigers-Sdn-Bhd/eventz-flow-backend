class Plan < ApplicationRecord
  belongs_to :event
  has_many :plan_objects, dependent: :destroy
  
  has_secure_token :share_token

  validates :name, presence: true
  validates :canvas_width, numericality: { greater_than: 0 }, allow_nil: true
  validates :canvas_height, numericality: { greater_than: 0 }, allow_nil: true
end