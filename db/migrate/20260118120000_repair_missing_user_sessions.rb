class RepairMissingUserSessions < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:user_sessions)
      create_table :user_sessions do |t|
        t.references :user, null: false, foreign_key: true
        t.string :jti, null: false
        t.string :refresh_token_hash, null: false
        t.string :device_name
        t.string :ip_address
        t.string :user_agent
        t.datetime :last_used_at
        t.datetime :expires_at, null: false
        t.boolean :revoked, default: false, null: false

        t.timestamps
      end

      add_index :user_sessions, :jti, unique: true
      add_index :user_sessions, :refresh_token_hash, unique: true
      add_index :user_sessions, [:user_id, :revoked]
      add_index :user_sessions, :expires_at
      add_index :user_sessions, :last_used_at
    end
  end
end
