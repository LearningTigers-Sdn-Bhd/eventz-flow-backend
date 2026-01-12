class CreateEventSponsorships < ActiveRecord::Migration[8.0]
  def change
    create_table :event_sponsorships do |t|
      t.references :group, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.references :sponsor, null: false, foreign_key: true
      t.references :event_sponsorship_tier, foreign_key: true, null: true
      t.string :tier_name_snapshot
      t.string :title, null: false
      t.integer :sponsorship_type, default: 0
      t.string :currency, default: "MYR"
      t.decimal :total_sponsor_amount, precision: 12, scale: 2
      t.decimal :received_total, precision: 12, scale: 2, default: 0
      t.datetime :last_received_at
      t.text :description
      t.integer :status, default: 0
      t.string :contact_name
      t.string :contact_email
      t.string :contact_whatsapp
      t.string :contact_position
      t.references :internal_owner_user, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.text :cancel_reason
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :event_sponsorships, :deleted_at
    add_index :event_sponsorships, [:event_id, :sponsor_id, :title], unique: true, name: 'index_event_sponsorships_uniqueness'
  end
end