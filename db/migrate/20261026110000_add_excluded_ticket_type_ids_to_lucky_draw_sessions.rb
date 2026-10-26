class AddExcludedTicketTypeIdsToLuckyDrawSessions < ActiveRecord::Migration[8.0]
  def change
    # Tickets of these types are left out of the draw pool (never drawn as winners).
    add_column :lucky_draw_sessions, :excluded_ticket_type_ids, :bigint, array: true, default: [], null: false
  end
end
