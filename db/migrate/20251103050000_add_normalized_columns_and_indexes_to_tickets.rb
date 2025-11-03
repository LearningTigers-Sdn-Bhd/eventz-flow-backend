class AddNormalizedColumnsAndIndexesToTickets < ActiveRecord::Migration[8.0]
  def change
    # Normalized columns for deduplication (app-level normalization, no citext)
    add_column :tickets, :attendee_email_norm, :string
    add_column :tickets, :attendee_phone_norm, :string
    add_column :tickets, :attendee_name_norm, :string

    # Partial unique indexes to enforce dedupe rules under concurrency
    add_index :tickets, [:event_id, :attendee_email_norm], unique: true, where: "attendee_email_norm IS NOT NULL", name: "idx_tickets_event_email_norm_unique"
    add_index :tickets, [:event_id, :attendee_phone_norm], unique: true, where: "attendee_phone_norm IS NOT NULL", name: "idx_tickets_event_phone_norm_unique"
    add_index :tickets, [:event_id, :ticket_type_id, :attendee_name_norm], unique: true, where: "attendee_email_norm IS NULL AND attendee_phone_norm IS NULL", name: "idx_tickets_event_type_name_norm_unique"
  end
end
