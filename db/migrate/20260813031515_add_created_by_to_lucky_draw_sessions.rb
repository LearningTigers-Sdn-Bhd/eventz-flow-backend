class AddCreatedByToLuckyDrawSessions < ActiveRecord::Migration[8.0]
  def change
    add_reference :lucky_draw_sessions, :created_by, foreign_key: { to_table: :users }, null: true
  end
end
