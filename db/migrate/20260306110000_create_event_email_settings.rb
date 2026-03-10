class CreateEventEmailSettings < ActiveRecord::Migration[8.0]
  def up
    create_table :event_email_settings do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.string :sender_name
      t.string :sender_address
      t.string :contact_email
      t.string :payment_receipt_email
      t.timestamps
    end

    # Migrate existing payment_receipt_email data from events
    execute <<-SQL
      INSERT INTO event_email_settings (event_id, payment_receipt_email, created_at, updated_at)
      SELECT id, payment_receipt_email, NOW(), NOW()
      FROM events
      WHERE payment_receipt_email IS NOT NULL AND payment_receipt_email != ''
    SQL

    remove_column :events, :payment_receipt_email, :string
  end

  def down
    add_column :events, :payment_receipt_email, :string

    execute <<-SQL
      UPDATE events
      SET payment_receipt_email = event_email_settings.payment_receipt_email
      FROM event_email_settings
      WHERE events.id = event_email_settings.event_id
    SQL

    drop_table :event_email_settings
  end
end
