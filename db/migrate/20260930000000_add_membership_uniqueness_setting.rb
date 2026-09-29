class AddMembershipUniquenessSetting < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :require_unique_membership_numbers, :boolean, default: true, null: false
    add_column :tickets, :require_unique_membership_numbers, :boolean, default: true, null: false

    # Preserve the previous membership policy for existing multi-ticket events.
    execute "UPDATE events SET require_unique_membership_numbers = false WHERE allow_multiple_tickets_per_email = true"
    execute <<~SQL
      UPDATE tickets SET require_unique_membership_numbers = events.require_unique_membership_numbers
      FROM events WHERE tickets.event_id = events.id
    SQL

    remove_index :tickets, name: 'idx_tickets_unique_membership_no'
    add_index :tickets, "event_id, lower(custom_fields_data->>'membership_no')",
              name: 'idx_tickets_unique_membership_no', unique: true,
              where: "deleted_at IS NULL AND status <> 3 AND NULLIF(custom_fields_data->>'membership_no', '') IS NOT NULL AND require_unique_membership_numbers = true"
  end

  def down
    remove_index :tickets, name: 'idx_tickets_unique_membership_no'
    add_index :tickets, "event_id, lower(custom_fields_data->>'membership_no')",
              name: 'idx_tickets_unique_membership_no', unique: true,
              where: "deleted_at IS NULL AND status <> 3 AND NULLIF(custom_fields_data->>'membership_no', '') IS NOT NULL AND allow_multiple_tickets_per_email IS NOT TRUE"
    remove_column :tickets, :require_unique_membership_numbers
    remove_column :events, :require_unique_membership_numbers
  end
end
