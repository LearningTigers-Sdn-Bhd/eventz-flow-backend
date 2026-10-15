class CreateBusinessMatchingSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :business_matching_sessions do |t|
      t.references :event, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :slot_duration, default: 30, null: false
      t.string :location
      t.string :admin_email
      t.string :admin_wa_number
      t.string :start_time, default: "09:00", null: false
      t.string :end_time, default: "17:00", null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
  end
end
