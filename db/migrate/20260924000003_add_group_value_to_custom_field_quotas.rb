class AddGroupValueToCustomFieldQuotas < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_field_quotas, :group_value, :string
    change_column_null :custom_field_quotas, :quota, true
  end
end
