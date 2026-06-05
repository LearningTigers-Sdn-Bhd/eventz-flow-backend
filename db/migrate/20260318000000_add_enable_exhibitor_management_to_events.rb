class AddEnableExhibitorManagementToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :enable_exhibitor_management, :boolean, default: false, null: false
  end
end
