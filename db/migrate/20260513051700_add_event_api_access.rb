class AddEventApiAccess < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_api_access, :boolean, default: false, null: false
    add_reference :api_keys, :event, null: true, foreign_key: true
  end
end
