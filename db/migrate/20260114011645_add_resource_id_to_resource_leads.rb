class AddResourceIdToResourceLeads < ActiveRecord::Migration[8.0]
  def change
    add_reference :resource_leads, :resource, null: false, foreign_key: true
  end
end
