class CreateShortLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :short_links do |t|
      t.string :code, null: false
      t.string :kind, null: false
      t.references :event, null: false, foreign_key: true
      t.jsonb :payload, null: false, default: {}
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :short_links, :code, unique: true
    add_index :short_links, %i[event_id kind]
  end
end
