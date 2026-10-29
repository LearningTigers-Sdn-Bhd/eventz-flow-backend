class AddNameToEmailBlasts < ActiveRecord::Migration[8.0]
  def change
    # Only set on templates (status 'template'), which are reusable starting points, never sent.
    add_column :email_blasts, :name, :string
  end
end
