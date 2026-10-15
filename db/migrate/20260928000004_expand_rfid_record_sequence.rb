class ExpandRfidRecordSequence < ActiveRecord::Migration[8.0]
  def change
    change_column :rfid_observations, :device_record_seq, :decimal, precision: 20, scale: 0
  end
end
