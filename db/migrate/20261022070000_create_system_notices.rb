class CreateSystemNotices < ActiveRecord::Migration[8.0]
  def change
    # Singleton row: the planned-maintenance heads-up shown as a banner in the
    # panel. Editable by org owners, readable without login.
    create_table :system_notices do |t|
      t.text :message, null: false, default: ''
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    add_check_constraint :system_notices, 'char_length(message) <= 300', name: 'chk_system_notices_message_length'
  end
end
