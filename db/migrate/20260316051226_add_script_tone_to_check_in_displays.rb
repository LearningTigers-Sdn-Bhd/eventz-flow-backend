class AddScriptToneToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :script_tone, :string
  end
end
