class AddRsvpFieldsToVisitors < ActiveRecord::Migration[8.0]
  def change
    add_column :visitors, :rsvp_status, :integer, default: 0
    add_column :visitors, :rsvp_responded_at, :datetime
    add_reference :visitors, :added_by, foreign_key: { to_table: :visitors }, null: true

    add_index :visitors, :rsvp_status
  end
end
