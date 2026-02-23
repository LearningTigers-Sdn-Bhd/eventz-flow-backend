class AddRegisteredByEmailToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :registered_by_email, :string
    add_index :tickets, [:event_id, :registered_by_email],
              name: 'idx_tickets_event_registered_by_email',
              where: 'registered_by_email IS NOT NULL'
  end
end
