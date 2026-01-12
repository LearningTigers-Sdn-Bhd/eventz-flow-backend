class AddCheckInFieldsToVisitors < ActiveRecord::Migration[8.0]
  def change
    add_column :visitors, :checked_in, :boolean, default: false, null: false
    add_column :visitors, :check_in_at, :datetime
    add_column :visitors, :scanned_by_id, :bigint

    add_index :visitors, :scanned_by_id
    add_foreign_key :visitors, :users, column: :scanned_by_id
  end
end
