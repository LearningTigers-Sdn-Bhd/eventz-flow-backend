class CreateTicketTypePriceTiers < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_type_price_tiers do |t|
      t.references :ticket_type, null: false, foreign_key: true
      t.string :label, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.timestamps
    end

    add_index :ticket_type_price_tiers, [:ticket_type_id, :starts_at], name: 'idx_price_tiers_on_ticket_type_and_start'
  end
end
