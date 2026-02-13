class CreateRegistrationForms < ActiveRecord::Migration[8.0]
  def change
    create_table :registration_forms do |t|
      t.references :event, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :position

      t.timestamps
    end

    add_index :registration_forms, [:event_id, :slug], unique: true
  end
end
