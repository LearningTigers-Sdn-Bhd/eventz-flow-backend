class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_hash, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :revoked_at, index: true

      t.timestamps
    end
  end
end
