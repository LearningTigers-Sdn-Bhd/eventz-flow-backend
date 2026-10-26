class AddWinnersPerDrawToLuckyDrawSessions < ActiveRecord::Migration[8.0]
  def change
    # How many winners one click of Draw picks. 1 keeps the classic one-by-one draw.
    add_column :lucky_draw_sessions, :winners_per_draw, :integer, null: false, default: 1
    add_check_constraint :lucky_draw_sessions, 'winners_per_draw BETWEEN 1 AND 200',
                         name: 'chk_lucky_draw_sessions_winners_per_draw'
  end
end
