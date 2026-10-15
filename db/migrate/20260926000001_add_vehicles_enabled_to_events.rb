class AddVehiclesEnabledToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :vehicles_enabled, :boolean,
               default: false, null: false
  end
end
