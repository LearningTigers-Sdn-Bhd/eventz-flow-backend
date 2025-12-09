class CreateEventRentableItems < ActiveRecord::Migration[8.0]
  def change
    create_table :event_rentable_items do |t|
      t.references :event, null: false, foreign_key: true
      t.references :rentable_item, null: false, foreign_key: true

      t.timestamps
    end
  end
end
