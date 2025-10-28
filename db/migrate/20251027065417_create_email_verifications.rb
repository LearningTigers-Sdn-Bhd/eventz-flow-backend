class CreateEmailVerifications < ActiveRecord::Migration[8.0]
  def change
    create_table :email_verifications do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :hashed_code, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
