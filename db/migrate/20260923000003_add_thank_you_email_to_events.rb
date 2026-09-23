class AddThankYouEmailToEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :thank_you_sent_at, :datetime
    add_column :event_email_settings, :thank_you_include_feedback, :boolean, default: false, null: false

    # Events that already ended before this feature shipped must never get the
    # thank-you email, so mark them as handled up front.
    execute <<~SQL.squish
      UPDATE events SET thank_you_sent_at = NOW() WHERE end_date IS NULL OR end_date < NOW()
    SQL
  end

  def down
    remove_column :event_email_settings, :thank_you_include_feedback
    remove_column :events, :thank_you_sent_at
  end
end
