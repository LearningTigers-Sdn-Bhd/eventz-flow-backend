class CreateEventLocation < ActiveRecord::Migration[8.0]
  def change
    create_table :event_locations do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :scan_limit, default: 0, null: false

      t.timestamps
    end

    add_index :event_locations, [:event_id, :name], unique: true
  end
end
