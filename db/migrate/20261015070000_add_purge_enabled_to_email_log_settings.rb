class AddPurgeEnabledToEmailLogSettings < ActiveRecord::Migration[8.0]
  def change
    # Deleting email log rows is opt-in: nothing is purged until an org owner
    # turns it on in the Retention dialog.
    add_column :email_log_settings, :purge_enabled, :boolean, null: false, default: false
  end
end
