class CreateEmailLogSettings < ActiveRecord::Migration[8.0]
  def change
    # Singleton row: how long the Email Log keeps rows. Editable by org owners.
    create_table :email_log_settings do |t|
      t.integer :retention_days, null: false, default: 730
      t.integer :protected_retention_days, null: false, default: 1825

      t.timestamps
    end

    add_check_constraint :email_log_settings, 'retention_days BETWEEN 30 AND 3650', name: 'chk_email_log_settings_retention_range'
    add_check_constraint :email_log_settings, 'protected_retention_days BETWEEN 30 AND 3650', name: 'chk_email_log_settings_protected_range'
    add_check_constraint :email_log_settings, 'protected_retention_days >= retention_days', name: 'chk_email_log_settings_protected_gte_retention'
  end
end
