# Lets a staff correction target a guest, not a visit or station (cert overrides).
class AddTicketToRfidCorrections < ActiveRecord::Migration[8.0]
  def change
    add_reference :rfid_corrections, :ticket, foreign_key: true, index: false
    add_index :rfid_corrections, %i[event_id ticket_id], name: 'idx_rfid_corrections_event_ticket'
  end
end
