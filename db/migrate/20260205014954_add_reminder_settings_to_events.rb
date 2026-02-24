class AddReminderSettingsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :reminders_enabled, :boolean, default: true
    add_column :events, :reminder_7_day, :boolean, default: true
    add_column :events, :reminder_1_day, :boolean, default: true
  end
end
