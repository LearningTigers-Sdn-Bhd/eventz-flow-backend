class AddCustomFieldsDataToVisitors < ActiveRecord::Migration[8.0]
  def change
    add_column :visitors, :custom_fields_data, :jsonb, default: {}
  end
end
