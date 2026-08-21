class AddEmailTogglesToEventEmailSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :event_email_settings, :emails_enabled, :boolean, null: false, default: true
    add_column :event_email_settings, :disabled_categories, :jsonb, null: false, default: []
  end
end
