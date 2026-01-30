class AddVoiceSettingsToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :voice_enabled, :boolean, default: true
    add_column :check_in_displays, :voice_type, :string, default: 'en-US-female'
  end
end
