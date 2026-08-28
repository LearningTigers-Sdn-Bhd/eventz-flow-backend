class BackfillScanLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    backfill(Ticket, 'Ticket')
    backfill(Visitor, 'Visitor')
  end

  def down
    execute 'DELETE FROM scan_logs'
  end

  private

  def backfill(model, type_name)
    model.where(checked_in: true).find_in_batches(batch_size: 1000) do |batch|
      rows = batch.map do |record|
        {
          event_id: record.event_id,
          scannable_type: type_name,
          scannable_id: record.id,
          event_location_id: nil,
          scanned_by_id: record.scanned_by_id,
          scanned_at: record.check_in_at || record.updated_at,
          source: record.scanned_by_id.present? ? 0 : 1,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      ScanLog.insert_all(rows) if rows.any?
    end
  end
end
