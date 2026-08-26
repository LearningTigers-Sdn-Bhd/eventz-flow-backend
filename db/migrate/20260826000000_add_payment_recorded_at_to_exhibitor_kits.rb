class AddPaymentRecordedAtToExhibitorKits < ActiveRecord::Migration[8.0]
  def up
    add_column :exhibitor_kits, :payment_recorded_at, :datetime

    # Backfill from updated_at for kits that already carry a money-relevant status - this is a
    # best-effort approximation (same accuracy analytics already had), frozen at migration time.
    # Going forward, the model callback keeps this column accurate on every real status change.
    execute <<~SQL.squish
      UPDATE exhibitor_kits
      SET payment_recorded_at = updated_at
      WHERE payment_status IN (1, 2, 3, 4)
    SQL
  end

  def down
    remove_column :exhibitor_kits, :payment_recorded_at
  end
end
