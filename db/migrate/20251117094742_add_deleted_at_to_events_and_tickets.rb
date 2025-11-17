class AddDeletedAtToEventsAndTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :deleted_at, :datetime
    add_index :events, :deleted_at

    add_column :tickets, :deleted_at, :datetime
    add_index :tickets, :deleted_at
  end
end
