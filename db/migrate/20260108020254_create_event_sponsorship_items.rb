class CreateEventSponsorshipItems < ActiveRecord::Migration[8.0]
  def change
    create_table :event_sponsorship_items do |t|
      t.references :event_sponsorship, null: false, foreign_key: true
      t.integer :item_type
      t.string :title
      t.integer :quantity
      t.decimal :unit_value, precision: 12, scale: 2
      t.decimal :total_value, precision: 12, scale: 2
      t.text :notes

      t.timestamps
    end
  end
end