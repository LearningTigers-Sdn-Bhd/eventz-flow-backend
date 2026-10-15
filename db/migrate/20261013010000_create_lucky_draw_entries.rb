# frozen_string_literal: true

class CreateLuckyDrawEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :lucky_draw_entries do |t|
      t.references :lucky_draw_session, null: false, foreign_key: true
      t.references :ticket, foreign_key: { on_delete: :cascade }
      t.references :visitor, foreign_key: { on_delete: :cascade }
      t.references :scanned_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    add_index :lucky_draw_entries, %i[lucky_draw_session_id ticket_id], unique: true,
              where: 'ticket_id IS NOT NULL', name: 'idx_lucky_draw_entries_session_ticket'
    add_index :lucky_draw_entries, %i[lucky_draw_session_id visitor_id], unique: true,
              where: 'visitor_id IS NOT NULL', name: 'idx_lucky_draw_entries_session_visitor'
    add_check_constraint :lucky_draw_entries,
                         '(ticket_id IS NOT NULL AND visitor_id IS NULL) OR (ticket_id IS NULL AND visitor_id IS NOT NULL)',
                         name: 'lucky_draw_entries_exactly_one_participant'
  end
end
