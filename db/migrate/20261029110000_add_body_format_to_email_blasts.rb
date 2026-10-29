class AddBodyFormatToEmailBlasts < ActiveRecord::Migration[8.0]
  def change
    # 'rich' = written in the editor and wrapped in the EventzFlow layout;
    # 'html' = organizer-supplied HTML sent as the whole email.
    add_column :email_blasts, :body_format, :string, null: false, default: 'rich'
  end
end
