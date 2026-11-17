class AddTicketGroupFillModeToEvents < ActiveRecord::Migration[8.0]
  def change
    # How a group fills its priority ticket types: "mixed" (evenly) or "ordered" (first pick first).
    add_column :events, :ticket_group_fill_mode, :string, default: 'mixed', null: false
  end
end
