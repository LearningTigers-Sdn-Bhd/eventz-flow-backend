class CreatePlanObjects < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_objects do |t|
      t.references :plan, null: false, foreign_key: true
      t.integer :object_type
      t.string :layer
      t.float :x
      t.float :y
      t.float :rotation, default: 0.0
      t.float :width
      t.float :height
      t.string :label
      t.integer :capacity
      t.boolean :locked, default: false
      t.integer :z_index, default: 0

      t.timestamps
    end
  end
end
