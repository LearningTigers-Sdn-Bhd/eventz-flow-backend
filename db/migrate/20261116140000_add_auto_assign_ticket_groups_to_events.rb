class AddAutoAssignTicketGroupsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :auto_assign_ticket_groups, :boolean, default: false, null: false
  end
end
