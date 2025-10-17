class CreateTicketTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_types do |t|
      # Associations
      t.references :event, null: true, foreign_key: true
      
      # Core Ticket Details
      t.string :name, null: false
      t.decimal :price, precision: 8, scale: 2, null: false, default: 0.00
      t.integer :quantity, null: false, default: 0 # Total quantity available
      t.integer :max_per_order, null: false, default: 10
      t.datetime :sale_starts_at # When sales start
      t.datetime :sale_ends_at # When sales end

      # Status and Behavior
      t.integer :status, default: 0 # 0: draft, 1: published, 2: archived
      t.boolean :hidden, default: false # If true, only visible via direct link/staff
      
      # JSONB for Custom Fields
      t.jsonb :custom_fields_data, default: {} 
      
      t.timestamps
    end
    
    # Add index for efficient lookups by event and status/name
    add_index :ticket_types, [:event_id, :status]
  end
end
