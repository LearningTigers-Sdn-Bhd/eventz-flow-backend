class AddUniqueNoIcIndexToTickets < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # KITA stores the IC under `no_ic`, not `ic_passport_no`; same per-event
  # uniqueness rule as idx_tickets_unique_ic_passport_no.
  def change
    add_index :tickets,
              "event_id, lower(custom_fields_data->>'no_ic')",
              name: 'idx_tickets_unique_no_ic',
              unique: true,
              where: "deleted_at IS NULL AND status <> 3 AND NULLIF(custom_fields_data->>'no_ic', '') IS NOT NULL AND allow_multiple_tickets_per_email IS NOT TRUE",
              algorithm: :concurrently
  end
end
