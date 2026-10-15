class AddAllowMultipleTicketsPerEmailToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :allow_multiple_tickets_per_email, :boolean,
               default: false, null: false
  end
end
