class RelaxUniqueIdentityIndexesForMultiTicketEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_index :tickets,
              "event_id, lower(custom_fields_data->>'ic_passport_no')",
              name: 'idx_tickets_unique_ic_passport_no_v2',
              unique: true,
              where: "deleted_at IS NULL AND status <> 3 AND NULLIF(custom_fields_data->>'ic_passport_no', '') IS NOT NULL AND allow_multiple_tickets_per_email IS NOT TRUE",
              algorithm: :concurrently
    remove_index :tickets, name: 'idx_tickets_unique_ic_passport_no', algorithm: :concurrently
    rename_index :tickets, 'idx_tickets_unique_ic_passport_no_v2', 'idx_tickets_unique_ic_passport_no'

    add_index :tickets,
              "event_id, lower(custom_fields_data->>'membership_no')",
              name: 'idx_tickets_unique_membership_no_v2',
              unique: true,
              where: "deleted_at IS NULL AND status <> 3 AND NULLIF(custom_fields_data->>'membership_no', '') IS NOT NULL AND allow_multiple_tickets_per_email IS NOT TRUE",
              algorithm: :concurrently
    remove_index :tickets, name: 'idx_tickets_unique_membership_no', algorithm: :concurrently
    rename_index :tickets, 'idx_tickets_unique_membership_no_v2', 'idx_tickets_unique_membership_no'
  end

  def down
    add_index :tickets,
              "event_id, lower(custom_fields_data->>'ic_passport_no')",
              name: 'idx_tickets_unique_ic_passport_no_v2',
              unique: true,
              where: "deleted_at IS NULL AND status <> 3 AND NULLIF(custom_fields_data->>'ic_passport_no', '') IS NOT NULL",
              algorithm: :concurrently
    remove_index :tickets, name: 'idx_tickets_unique_ic_passport_no', algorithm: :concurrently
    rename_index :tickets, 'idx_tickets_unique_ic_passport_no_v2', 'idx_tickets_unique_ic_passport_no'

    add_index :tickets,
              "event_id, lower(custom_fields_data->>'membership_no')",
              name: 'idx_tickets_unique_membership_no_v2',
              unique: true,
              where: "deleted_at IS NULL AND status <> 3 AND NULLIF(custom_fields_data->>'membership_no', '') IS NOT NULL",
              algorithm: :concurrently
    remove_index :tickets, name: 'idx_tickets_unique_membership_no', algorithm: :concurrently
    rename_index :tickets, 'idx_tickets_unique_membership_no_v2', 'idx_tickets_unique_membership_no'
  end
end
