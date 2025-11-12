class CreateUserEngageVendors < ActiveRecord::Migration[8.0]
  def change
    create_table :user_engage_vendors do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :vendor_profile, null: false, foreign_key: true
      t.integer :time_away_duration

      t.timestamps
    end
  end
end
