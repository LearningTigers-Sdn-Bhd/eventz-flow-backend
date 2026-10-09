# frozen_string_literal: true

class AddScannedRangeToLuckyDrawSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :lucky_draw_sessions, :scanned_from, :date
    add_column :lucky_draw_sessions, :scanned_to, :date
  end
end
