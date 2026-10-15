# frozen_string_literal: true

class AddScannedOnlyToLuckyDrawSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :lucky_draw_sessions, :scanned_only, :boolean, default: false, null: false
  end
end
