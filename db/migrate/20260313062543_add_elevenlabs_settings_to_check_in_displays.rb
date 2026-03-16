class AddElevenlabsSettingsToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :elevenlabs_settings, :jsonb, default: {}
  end
end
