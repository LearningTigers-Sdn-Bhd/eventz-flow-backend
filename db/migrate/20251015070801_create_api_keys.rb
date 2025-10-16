class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key_hash, null: false, index: { unique: true }
      t.datetime :last_used_at, index: true
      t.boolean :is_active, default: true, null: false
      t.timestamps
    end
  end
end
