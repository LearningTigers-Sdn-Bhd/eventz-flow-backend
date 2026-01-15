class AddRoleToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :role, :string
  end
end
