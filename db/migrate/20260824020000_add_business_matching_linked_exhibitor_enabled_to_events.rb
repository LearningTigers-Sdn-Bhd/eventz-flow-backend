class AddBusinessMatchingLinkedExhibitorEnabledToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :business_matching_linked_exhibitor_enabled, :boolean, default: false, null: false
  end
end
