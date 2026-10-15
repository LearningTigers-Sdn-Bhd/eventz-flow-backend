class AddPositionToCustomFieldQuotas < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_field_quotas, :position, :integer
  end
end
