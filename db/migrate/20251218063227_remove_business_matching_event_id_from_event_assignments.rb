class RemoveBusinessMatchingEventIdFromEventAssignments < ActiveRecord::Migration[8.0]
  def change
    remove_column :event_assignments, :business_matching_event_id, :string
  end
end
