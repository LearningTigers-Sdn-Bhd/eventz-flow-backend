class CreateEventAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :event_assignments do |t|
      # Foreign keys to link the assignment to a User and an Event
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      # The role of the user for this specific event (e.g., 'event_admin', 'event_team_member')
      # Assuming you will use a simple string or an enum in the model for validation.
      t.string :role, null: false

      t.timestamps

      # Constraint: A user can only have one assignment role per event.
      # This prevents duplicate staff entries for the same event.
      t.index [:event_id, :user_id], unique: true
    end
  end
end