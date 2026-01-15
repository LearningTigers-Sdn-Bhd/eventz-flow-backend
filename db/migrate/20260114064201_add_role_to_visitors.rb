class AddRoleToVisitors < ActiveRecord::Migration[8.0]
  def change
    add_column :visitors, :role, :string
  end
end
