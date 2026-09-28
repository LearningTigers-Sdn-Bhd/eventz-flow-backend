# A staff correction now has two targets: a manual exit names the entry
# observation it closes, and a station role/UID-rule change names the station.
# The audit row is the same shape either way: actor, reason, time, target.
class RfidCorrectionTargets < ActiveRecord::Migration[8.0]
  def change
    change_column_null :rfid_corrections, :entry_observation_id, true
    change_column_null :rfid_corrections, :exit_at, true
    add_reference :rfid_corrections, :station,
                  foreign_key: { to_table: :rfid_stations, on_delete: :nullify }
    add_column :rfid_corrections, :details, :jsonb, null: false, default: {}
  end
end
