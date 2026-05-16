class CreateEmailDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :email_deliveries do |t|
      t.string :provider, null: false, default: 'resend'
      t.string :provider_message_id
      t.string :mailer_name, null: false
      t.string :mailer_action, null: false
      t.string :recipient
      t.jsonb :recipients, null: false, default: {}
      t.string :subject
      t.string :status, null: false, default: 'queued'
      t.references :related, polymorphic: true, null: true
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :failed_at
      t.datetime :bounced_at
      t.datetime :complained_at
      t.datetime :suppressed_at
      t.text :last_error
      t.string :failure_reason
      t.integer :retry_count, null: false, default: 0
      t.datetime :next_retry_at
      t.references :resend_of, foreign_key: { to_table: :email_deliveries }, null: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :email_deliveries, :provider_message_id, unique: true, where: 'provider_message_id IS NOT NULL'
    add_index :email_deliveries, :status
    add_index :email_deliveries, :recipient
    add_index :email_deliveries, %i[mailer_name mailer_action]
    add_index :email_deliveries, :created_at
  end
end
