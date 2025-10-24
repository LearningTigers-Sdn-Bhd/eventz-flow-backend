class CreateTickets < ActiveRecord::Migration[8.0]
  def change
    # Ensure you have already run the migration for UUID generation if needed:
    # enable_extension 'pgcrypto' 

    create_table :tickets do |t|
      # UUID for external use, scanning, and security (Public ID)
      t.uuid :public_id, null: false, default: 'gen_random_uuid()'

      # Associations
      t.references :event, null: false, foreign_key: true
      t.references :ticket_type, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      # t.references :order # Anticipating an Order model for payment grouping (hidden for now)

      # Attendee Details
      t.string :attendee_name, null: false
      t.string :attendee_email, null: false
      t.string :attendee_phone

      # Operational Status
      t.boolean :checked_in, null: false, default: false
      t.datetime :check_in_at
      t.references :scanned_by, foreign_key: { to_table: :users }, null: true
      t.integer :status, null: false, default: 0 # 0: purchased, 1: scanned, 2: refunded, 3: canceled

      # Payment Fields
      t.integer :payment_status, default: 0, null: false
      t.string :payment_screenshot_url
      t.string :transaction_id
      t.string :payment_method

      # Custom Fields (JSONB to store data captured during registration)
      t.jsonb :custom_fields_data, default: {}
      
      t.timestamps
    end

    # Add a unique index on the public_id for fast lookups (scanning/external APIs)
    add_index :tickets, :public_id, unique: true
    # Add a composite index for efficient lookups of tickets for a specific event
    add_index :tickets, [:event_id, :status]
  end
end
