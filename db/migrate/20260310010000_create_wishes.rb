class CreateWishes < ActiveRecord::Migration[8.0]
  def change
    create_table :wishes do |t|
      t.references :event, null: false, foreign_key: true
      t.references :visitor, null: true, foreign_key: true
      t.string :guest_name, null: false
      t.text :message, null: false
      t.integer :status, null: false, default: 0
      t.datetime :approved_at

      t.timestamps
    end

    add_index :wishes, %i[event_id status]
  end
end
