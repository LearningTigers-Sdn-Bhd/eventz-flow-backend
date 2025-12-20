class AddBusinessMatchingEventIdToEventAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :event_assignments, :business_matching_event_id, :string
  end
end
