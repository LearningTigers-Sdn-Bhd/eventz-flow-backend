class AddActivePlanAndArrivalTracking < ActiveRecord::Migration[8.0]
  def change
    add_reference :check_in_displays, :active_plan, foreign_key: { to_table: :plans }, null: true
    add_column :table_assignments, :arrived_at, :datetime
  end
end
