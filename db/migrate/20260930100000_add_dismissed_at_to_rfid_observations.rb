# An org owner can dismiss a reading from the Anomalies list without deleting
# it: the raw reading and its visit stay for audit and the CSV.
class AddDismissedAtToRfidObservations < ActiveRecord::Migration[8.0]
  def change
    add_column :rfid_observations, :dismissed_at, :datetime
  end
end
