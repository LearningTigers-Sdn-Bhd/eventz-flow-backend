class AddEventIdToEmailDeliveries < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_column :email_deliveries, :event_id, :bigint
    add_index :email_deliveries, %i[event_id mailer_action created_at],
              name: 'index_email_deliveries_on_event_action_created', algorithm: :concurrently

    # Backfill rows whose event is reachable through `related`. Rows with no
    # event path (system mail) stay NULL, same as the old for_event scope.
    execute <<~SQL.squish
      UPDATE email_deliveries d SET event_id = t.event_id
      FROM tickets t WHERE d.related_type = 'Ticket' AND d.related_id = t.id AND d.event_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE email_deliveries d SET event_id = t.event_id
      FROM ticket_applications a JOIN tickets t ON t.id = a.ticket_id
      WHERE d.related_type = 'TicketApplication' AND d.related_id = a.id AND d.event_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE email_deliveries d SET event_id = v.event_id
      FROM exhibitor_kits k JOIN event_vendors v ON v.id = k.event_vendor_id
      WHERE d.related_type = 'ExhibitorKit' AND d.related_id = k.id AND d.event_id IS NULL
    SQL
  end

  def down
    remove_index :email_deliveries, name: 'index_email_deliveries_on_event_action_created'
    remove_column :email_deliveries, :event_id
  end
end
