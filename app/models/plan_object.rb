class PlanObject < ApplicationRecord
  belongs_to :plan
  has_many :table_assignments, dependent: :destroy
  has_one_attached :image, dependent: :purge_later

  enum :object_type, { table: 0, wall: 1, door: 2, stage: 3, label: 4, floor: 5 }, prefix: true

  validates :x, presence: true
  validates :y, presence: true
  validates :width, numericality: { greater_than: 0 }, allow_nil: true
  validates :height, numericality: { greater_than: 0 }, allow_nil: true
  validates :capacity, numericality: { greater_than_or_equal_to: 0 }, if: :object_type_table?

  after_commit :update_plan_dimensions, if: :object_type_floor?

  private

  def update_plan_dimensions
    floor_objects = plan.plan_objects.object_type_floor
    if floor_objects.any?
      max_x = floor_objects.map { |o| (o.x || 0) + (o.width || 0) }.max || 0
      max_y = floor_objects.map { |o| (o.y || 0) + (o.height || 0) }.max || 0
      plan.update(canvas_width: max_x, canvas_height: max_y)
    elsif plan.canvas_width != 0 || plan.canvas_height != 0
      plan.update(canvas_width: 0, canvas_height: 0)
    end
  end
end