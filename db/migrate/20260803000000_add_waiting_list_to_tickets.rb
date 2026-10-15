class AddWaitingListToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :waiting_list, :boolean, null: false, default: false
    add_index :tickets, :waiting_list
  end
end
