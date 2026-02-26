class AddPathToPlanObjectsAndChangePlanDefaults < ActiveRecord::Migration[8.0]
  def change
    add_column :plan_objects, :path, :text
    change_column_default :plans, :canvas_width, from: nil, to: 0
    change_column_default :plans, :canvas_height, from: nil, to: 0
  end
end
