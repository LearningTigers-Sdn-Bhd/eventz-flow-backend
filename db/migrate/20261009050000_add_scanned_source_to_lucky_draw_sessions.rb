# frozen_string_literal: true

class AddScannedSourceToLuckyDrawSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :lucky_draw_sessions, :scanned_source, :string, default: 'ticket', null: false
  end
end
