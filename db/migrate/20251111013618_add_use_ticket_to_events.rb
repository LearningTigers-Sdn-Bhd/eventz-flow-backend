class AddUseTicketToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_ticket, :boolean, default: true, null: false
  end
end
