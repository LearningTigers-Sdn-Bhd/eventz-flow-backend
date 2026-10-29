class CreateEmailBlasts < ActiveRecord::Migration[8.0]
  def change
    create_table :email_blasts do |t|
      t.references :event, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.text :body, null: false, default: ''
      # { ticket_type_ids: [..] } - empty means every registered delegate.
      t.jsonb :audience, null: false, default: {}
      # draft -> sending; a blast is sent exactly once.
      t.string :status, null: false, default: 'draft'
      t.integer :recipient_count
      t.datetime :sent_at
      t.timestamps
    end
    add_index :email_blasts, %i[event_id created_at]
  end
end
