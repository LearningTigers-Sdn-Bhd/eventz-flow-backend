class AddTicketGroupExcludedTypeIdsToEvents < ActiveRecord::Migration[8.0]
  def change
    # Ticket types that are never placed in a ticket group (e.g. speakers, VIPs).
    add_column :events, :ticket_group_excluded_type_ids, :integer, array: true, default: [], null: false
  end
end
