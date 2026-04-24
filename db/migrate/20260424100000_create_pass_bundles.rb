class CreatePassBundles < ActiveRecord::Migration[8.0]
  def change
    create_table :pass_bundles do |t|
      t.references :event, null: false, foreign_key: true
      t.references :registration_form, null: false, foreign_key: true
      t.references :ticket_type, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :token, null: false
      t.integer :pass_limit, null: false
      t.integer :payment_mode, null: false, default: 0
      t.integer :payment_status, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :expires_at
      t.timestamps
    end

    add_index :pass_bundles, [:event_id, :token], unique: true
    add_index :pass_bundles, [:event_id, :status]
    add_check_constraint :pass_bundles, 'pass_limit >= 0', name: 'chk_pass_bundles_pass_limit_non_negative'
  end
end
