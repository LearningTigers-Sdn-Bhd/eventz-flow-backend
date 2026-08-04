class AddDateRangeToBusinessMatchingSessions < ActiveRecord::Migration[8.0]
  def up
    add_column :business_matching_sessions, :start_date, :date
    add_column :business_matching_sessions, :end_date, :date

    # Backfill existing sessions from their event's dates so the column can
    # be made non-null — sessions created after this migration set their own
    # range (independent of the event) at create/edit time.
    execute <<~SQL.squish
      UPDATE business_matching_sessions
      SET start_date = COALESCE(events.start_date::date, CURRENT_DATE),
          end_date = COALESCE(events.end_date::date, COALESCE(events.start_date::date, CURRENT_DATE))
      FROM events
      WHERE business_matching_sessions.event_id = events.id
    SQL

    change_column_null :business_matching_sessions, :start_date, false
    change_column_null :business_matching_sessions, :end_date, false
  end

  def down
    remove_column :business_matching_sessions, :start_date
    remove_column :business_matching_sessions, :end_date
  end
end
