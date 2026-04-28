class CreateTicketApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_applications do |t|
      t.references :ticket, null: false, foreign_key: true, index: { unique: true }
      t.references :registration_form, null: false, foreign_key: true
      t.integer :review_status, null: false, default: 0
      t.integer :rsvp_status, null: false, default: 0
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :rejection_reason
      t.string :rsvp_token_digest
      t.datetime :rsvp_sent_at
      t.datetime :rsvp_confirmed_at
      t.datetime :rsvp_expires_at

      t.timestamps
    end

    add_index :ticket_applications, :rsvp_token_digest, unique: true
    add_check_constraint :ticket_applications,
                         'review_status IN (0, 1, 2)',
                         name: 'chk_ticket_applications_review_status'
    add_check_constraint :ticket_applications,
                         'rsvp_status IN (0, 1, 2, 3, 4)',
                         name: 'chk_ticket_applications_rsvp_status'
  end
end
