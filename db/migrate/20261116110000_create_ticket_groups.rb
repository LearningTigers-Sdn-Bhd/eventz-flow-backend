class CreateTicketGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_groups do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      # Ticket type ids this group fills first, in the order they are filled.
      t.integer :priority_ticket_type_ids, array: true, default: [], null: false
      t.timestamps
    end
    add_index :ticket_groups, %i[event_id position], unique: true

    add_reference :tickets, :ticket_group, foreign_key: { on_delete: :nullify }
  end
end
