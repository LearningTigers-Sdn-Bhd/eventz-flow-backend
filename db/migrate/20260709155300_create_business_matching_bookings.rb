class CreateBusinessMatchingBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :business_matching_bookings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business_matching_session, null: false, foreign_key: true, index: { name: 'index_bm_bookings_on_bm_session_id' }
      t.references :host_user, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.date :booking_date, null: false
      t.string :booking_time, null: false
      t.integer :duration, default: 30, null: false
      t.string :status, default: "Pending", null: false
      t.string :payment_status, default: "Pending", null: false
      t.string :attendance
      t.text :host_comment
      t.decimal :potential_deal_value, precision: 12, scale: 2, default: 0.0

      t.timestamps
    end
    add_index :business_matching_bookings, [:host_user_id, :booking_date, :booking_time], name: 'index_bm_bookings_host_time_unique', unique: true, where: "status != 'Cancelled'"
  end
end
