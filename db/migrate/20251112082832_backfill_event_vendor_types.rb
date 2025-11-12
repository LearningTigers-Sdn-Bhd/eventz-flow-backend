class BackfillEventVendorTypes < ActiveRecord::Migration[8.0]
  def up
    # Backfill type based on event.use_ticket using raw SQL to avoid model dependencies
    execute <<-SQL
      UPDATE event_vendors
      SET type = CASE
        WHEN EXISTS (
          SELECT 1 FROM events
          WHERE events.id = event_vendors.event_id
          AND events.use_ticket = true
        ) THEN 'Exhibitor'
        ELSE 'Merchant'
      END
      WHERE type IS NULL
    SQL

    # Make type column non-nullable
    change_column_null :event_vendors, :type, false
  end

  def down
    change_column_null :event_vendors, :type, true
    execute "UPDATE event_vendors SET type = NULL"
  end
end
