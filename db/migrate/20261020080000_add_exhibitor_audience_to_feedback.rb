class AddExhibitorAudienceToFeedback < ActiveRecord::Migration[8.0]
  def up
    # One form per audience per event: 0 = ticket holders (existing), 1 = exhibitors.
    add_column :feedback_forms, :audience, :integer, null: false, default: 0
    remove_index :feedback_forms, :event_id
    add_index :feedback_forms, %i[event_id audience], unique: true

    add_reference :feedback_responses, :exhibitor, foreign_key: { to_table: :event_vendors }, index: false
    add_index :feedback_responses, :exhibitor_id
    add_index :feedback_responses, %i[feedback_form_id exhibitor_id], unique: true,
              where: 'exhibitor_id IS NOT NULL', name: 'idx_feedback_responses_one_per_exhibitor'

    add_column :event_email_settings, :thank_you_exhibitors, :boolean, default: false, null: false
    add_column :events, :exhibitor_thank_you_sent_at, :datetime
    # Events that already ended must never mass-mail exhibitors when this ships.
    execute <<~SQL.squish
      UPDATE events SET exhibitor_thank_you_sent_at = NOW() WHERE end_date IS NULL OR end_date < NOW()
    SQL
  end

  def down
    remove_column :events, :exhibitor_thank_you_sent_at
    remove_column :event_email_settings, :thank_you_exhibitors
    remove_index :feedback_responses, name: 'idx_feedback_responses_one_per_exhibitor'
    remove_reference :feedback_responses, :exhibitor, foreign_key: { to_table: :event_vendors }
    remove_index :feedback_forms, %i[event_id audience]
    add_index :feedback_forms, :event_id, unique: true
    remove_column :feedback_forms, :audience
  end
end
