class CreatePublicExhibitorAccessSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :public_exhibitor_access_sessions do |t|
      t.references :event, null: false, foreign_key: true
      t.string :normalized_email, null: false
      t.string :challenge_digest, null: false
      t.datetime :challenge_expires_at, null: false
      t.datetime :challenge_consumed_at
      t.string :session_digest
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :public_exhibitor_access_sessions, :challenge_digest, unique: true
    add_index :public_exhibitor_access_sessions, :session_digest, unique: true,
      where: 'session_digest IS NOT NULL'
    add_index :public_exhibitor_access_sessions, %i[event_id normalized_email]
  end
end
