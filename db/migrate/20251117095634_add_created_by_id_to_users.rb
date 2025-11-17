class AddCreatedByIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :created_by_id, :bigint, null: true
    add_index :users, :created_by_id
    add_foreign_key :users, :users, column: :created_by_id, on_delete: :nullify
  end
end
