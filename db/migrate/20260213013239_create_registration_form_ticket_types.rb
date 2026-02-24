class CreateRegistrationFormTicketTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :registration_form_ticket_types do |t|
      t.references :registration_form, null: false, foreign_key: true
      t.references :ticket_type, null: false, foreign_key: true
      t.integer :registration_mode, null: false, default: 0
      t.integer :min_attendees, null: false, default: 1
      t.integer :max_attendees
      t.jsonb :custom_labels_data, null: false, default: {}

      t.timestamps
    end

    add_index :registration_form_ticket_types, [:registration_form_id, :ticket_type_id],
              unique: true, name: 'idx_reg_form_ticket_types_unique'

    add_check_constraint :registration_form_ticket_types,
                         'min_attendees >= 1',
                         name: 'chk_reg_form_ticket_types_min_attendees'

    add_check_constraint :registration_form_ticket_types,
                         'max_attendees IS NULL OR max_attendees >= min_attendees',
                         name: 'chk_reg_form_ticket_types_max_attendees'
  end
end
