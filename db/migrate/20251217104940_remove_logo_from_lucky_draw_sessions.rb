class RemoveLogoFromLuckyDrawSessions < ActiveRecord::Migration[8.0]
  def change
    remove_column :lucky_draw_sessions, :logo, :string
  end
end
