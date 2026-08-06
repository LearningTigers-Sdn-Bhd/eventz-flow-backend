class AddTagsEditableToBusinessMatching < ActiveRecord::Migration[8.0]
  def change
    add_column :business_matching_sessions, :tags_editable, :boolean, default: true, null: false
    add_column :business_host_assignments, :tags_editable_override, :boolean
  end
end
