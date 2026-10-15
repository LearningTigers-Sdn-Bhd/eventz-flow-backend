class AddTableNumberToPlanObjects < ActiveRecord::Migration[8.0]
  def change
    add_column :plan_objects, :table_number, :string
  end
end
