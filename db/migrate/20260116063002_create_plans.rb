class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name
      t.float :canvas_width
      t.float :canvas_height
      t.float :pixels_per_unit, default: 20.0
      t.boolean :public_enabled, default: false
      t.string :share_token
      t.jsonb :settings_json

      t.timestamps
    end
    add_index :plans, :share_token, unique: true

  end
end
