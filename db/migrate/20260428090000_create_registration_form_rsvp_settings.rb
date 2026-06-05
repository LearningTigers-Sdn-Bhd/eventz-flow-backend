class CreateRegistrationFormRsvpSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :registration_form_rsvp_settings do |t|
      t.references :registration_form, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: false
      t.boolean :rsvp_required, null: false, default: false
      t.integer :rsvp_expires_in_hours
      t.integer :review_sla_hours, null: false, default: 48
      t.datetime :notify_by_date

      t.timestamps
    end

    add_check_constraint :registration_form_rsvp_settings,
                         'review_sla_hours > 0',
                         name: 'chk_registration_form_rsvp_settings_review_sla_positive'
    add_check_constraint :registration_form_rsvp_settings,
                         'rsvp_expires_in_hours IS NULL OR rsvp_expires_in_hours > 0',
                         name: 'chk_registration_form_rsvp_settings_expiry_positive'
  end
end
