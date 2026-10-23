# frozen_string_literal: true

class AddBmRemindersToEventEmailSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :event_email_settings, :business_matching_reminder_enabled, :boolean, default: true, null: false
    add_column :event_email_settings, :business_matching_reminder_2_day, :boolean, default: true, null: false
    add_column :event_email_settings, :business_matching_reminder_1_day, :boolean, default: true, null: false
    add_column :event_email_settings, :business_matching_reminder_1_hour, :boolean, default: true, null: false
  end
end
