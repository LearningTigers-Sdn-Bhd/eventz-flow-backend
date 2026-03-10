class AddSeatingPlanDurationToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :seating_plan_duration, :integer
  end
end
