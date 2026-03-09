class AddSeatingPlanToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :show_seating_plan, :boolean, default: false
    add_column :check_in_displays, :seating_plan_sidebar_position, :integer, default: 0
  end
end
