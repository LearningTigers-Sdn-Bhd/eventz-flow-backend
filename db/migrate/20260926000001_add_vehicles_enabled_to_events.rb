class AddVehiclesEnabledToEvents < ActiveRecord::Migration[8.0]
  def change
    # Guarded so a DB that already has the column can still migrate; a DB that
    # recorded this version never re-runs it.
    add_column :events, :vehicles_enabled, :boolean,
               default: false, null: false, if_not_exists: true
  end
end
