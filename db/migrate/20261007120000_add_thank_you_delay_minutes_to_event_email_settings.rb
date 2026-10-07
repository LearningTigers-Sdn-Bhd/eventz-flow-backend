# frozen_string_literal: true

class AddThankYouDelayMinutesToEventEmailSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :event_email_settings, :thank_you_delay_minutes, :integer, default: 120, null: false
  end
end
