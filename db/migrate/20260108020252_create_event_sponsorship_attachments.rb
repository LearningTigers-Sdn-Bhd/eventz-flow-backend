class CreateEventSponsorshipAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :event_sponsorship_attachments do |t|
      t.references :event_sponsorship, null: false, foreign_key: true
      t.references :event_sponsorship_payment, foreign_key: true, null: true
      t.integer :media_type
      t.integer :attachment_type
      t.string :file_name
      t.string :mime_type
      t.integer :file_size
      t.string :storage_disk
      t.string :storage_path
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :event_sponsorship_attachments, :deleted_at
  end
end