class CreateBusinessMatchingAvailabilities < ActiveRecord::Migration[8.0]
  def change
    create_table :business_matching_availabilities do |t|
      t.references :business_matching_session, null: false, foreign_key: true, index: { name: 'index_bm_availabilities_on_bm_session_id' }
      t.references :host_user, foreign_key: { to_table: :users }
      t.date :day, null: false
      t.string :start_time, null: false
      t.string :end_time, null: false

      t.timestamps
    end
    add_index :business_matching_availabilities, [:business_matching_session_id, :host_user_id, :day], name: 'idx_bm_availabilities_unique'
  end
end
