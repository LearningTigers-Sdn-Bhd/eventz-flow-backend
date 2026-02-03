class AddValidDatesToTicketTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :ticket_types, :valid_from_date, :date
    add_column :ticket_types, :valid_to_date, :date
  end
end
