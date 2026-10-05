# A correction aimed at a guest (manual entry, cert override, attendance
# notice) means nothing without the ticket, so it goes with the ticket.
# Without this, hard-deleting a ticket that was ever sent an attendance
# check raised a foreign key error.
class CascadeRfidCorrectionsOnTicketDelete < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :rfid_corrections, :tickets
    add_foreign_key :rfid_corrections, :tickets, on_delete: :cascade
  end
end
