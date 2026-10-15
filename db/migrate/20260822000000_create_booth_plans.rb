class CreateBoothPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :booth_plans do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :booth_plans, %i[event_id position]
  end
end
