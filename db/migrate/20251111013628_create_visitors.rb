class CreateVisitors < ActiveRecord::Migration[8.0]
  def change
    create_table :visitors do |t|
      t.references :event, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.string :full_name
      t.string :gender
      t.integer :age
      t.string :phone
      t.string :email

      t.timestamps
    end

    add_index :visitors, [:event_id, :vendor_id]
  end
end
