class AddVoiceRulesToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :voice_rules, :jsonb, default: []
  end
end
