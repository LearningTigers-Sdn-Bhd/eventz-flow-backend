class AddRegistrationPathTemplateToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :registration_path_template, :string
  end
end
