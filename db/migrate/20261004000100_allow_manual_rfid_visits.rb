# A staff "manual entry" visit has no gate reading behind it; it is owned by
# the correction that created it.
class AllowManualRfidVisits < ActiveRecord::Migration[8.0]
  def change
    change_column_null :rfid_visits, :entry_observation_id, true
    add_reference :rfid_visits, :correction, foreign_key: { to_table: :rfid_corrections, on_delete: :cascade }
  end
end
