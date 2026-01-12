class CreateEventSponsorshipTiers < ActiveRecord::Migration[8.0]
  def change
    create_table :event_sponsorship_tiers do |t|
      t.references :group, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :sponsorship_type_default
      t.string :currency_default, default: "MYR"
      t.decimal :suggested_value, precision: 12, scale: 2
      t.integer :capacity
      t.text :benefits
      t.integer :sort_order
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :event_sponsorship_tiers, [:event_id, :name], unique: true
    add_index :event_sponsorship_tiers, :deleted_at
  end
end