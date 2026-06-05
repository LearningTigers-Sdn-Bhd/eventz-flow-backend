class AddStateModesToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :idle_mode, :string
    add_column :check_in_displays, :announcement_mode, :string
    add_column :check_in_displays, :announcement_duration, :integer
  end
end
