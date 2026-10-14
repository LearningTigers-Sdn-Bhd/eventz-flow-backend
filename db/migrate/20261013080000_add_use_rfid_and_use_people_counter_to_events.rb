# frozen_string_literal: true

# Event feature toggles: RFID and the People Counter are hidden unless turned on.
# Both used to be always available, so events that already use them start with
# the toggle on; otherwise this migration would hide live work from their staff.
class AddUseRfidAndUsePeopleCounterToEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :use_rfid, :boolean, default: false, null: false
    add_column :events, :use_people_counter, :boolean, default: false, null: false

    execute <<~SQL.squish
      UPDATE events SET use_rfid = TRUE
      WHERE EXISTS (SELECT 1 FROM rfid_stations WHERE rfid_stations.event_id = events.id)
         OR EXISTS (SELECT 1 FROM rfid_bindings WHERE rfid_bindings.event_id = events.id)
         OR EXISTS (SELECT 1 FROM rfid_sessions WHERE rfid_sessions.event_id = events.id)
    SQL

    execute <<~SQL.squish
      UPDATE events SET use_people_counter = TRUE
      WHERE EXISTS (SELECT 1 FROM event_halls WHERE event_halls.event_id = events.id)
         OR EXISTS (SELECT 1 FROM people_counter_connections WHERE people_counter_connections.event_id = events.id)
    SQL
  end

  def down
    remove_column :events, :use_people_counter
    remove_column :events, :use_rfid
  end
end
