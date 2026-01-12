class CreateSponsors < ActiveRecord::Migration[8.0]
  def change
    create_table :sponsors do |t|
      t.references :group, null: false, foreign_key: true
      t.string :name, null: false
      t.string :website
      t.string :industry
      t.string :default_email
      t.string :default_whatsapp
      t.string :default_contact_name
      t.string :default_contact_position
      t.text :notes
      t.string :logo_path
      t.boolean :is_active, default: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :sponsors, [:group_id, :name], unique: true
    add_index :sponsors, :deleted_at
  end
end