class AddGuestPassLabelToTickets < ActiveRecord::Migration[8.0]
  def up
    # Company/group the pass belongs to. Set only by create_guest_passes, so it
    # tells guest passes apart from group-registration tickets (which share a
    # registration_batch_id too) and survives a pass being renamed.
    add_column :tickets, :guest_pass_label, :string

    # Passes made before this column existed: recover the label from the
    # "<label> Pax i/N" name create_guest_passes gave them. Only this new column
    # is written; guest passes always carry a registration_batch_id.
    execute <<~SQL.squish
      UPDATE tickets
      SET guest_pass_label = substring(attendee_name from '^(.+) Pax [0-9]+/[0-9]+$')
      WHERE registration_batch_id IS NOT NULL
        AND attendee_name ~ '^.+ Pax [0-9]+/[0-9]+$'
    SQL
  end

  def down
    remove_column :tickets, :guest_pass_label
  end
end
