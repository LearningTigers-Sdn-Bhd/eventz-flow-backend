class AddLastUsedAtIndexToUserSessions < ActiveRecord::Migration[8.0]
  def change
    add_index :user_sessions, :last_used_at
  end
end
