class AddStyleKeyToEmailBlasts < ActiveRecord::Migration[8.0]
  def change
    # Which header look the layout uses (announcement, important update...). Only applies to 'rich' emails.
    add_column :email_blasts, :style_key, :string, null: false, default: 'general'
  end
end
