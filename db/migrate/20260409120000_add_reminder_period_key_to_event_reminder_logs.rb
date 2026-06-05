class AddReminderPeriodKeyToEventReminderLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :event_reminder_logs, :reminder_period_key, :string

    remove_index :event_reminder_logs, %i[ticket_id reminder_type]

    add_index :event_reminder_logs, %i[ticket_id reminder_type], unique: true,
                                                                 where: 'reminder_period_key IS NULL',
                                                                 name: 'index_event_reminder_logs_on_ticket_and_type_when_period_null'
    add_index :event_reminder_logs, %i[ticket_id reminder_type reminder_period_key], unique: true,
                                                                                     where: 'reminder_period_key IS NOT NULL',
                                                                                     name: 'index_event_reminder_logs_on_ticket_type_and_period'

    add_check_constraint :event_reminder_logs,
                         "(reminder_type = 'payment_pending_weekly' AND reminder_period_key = BTRIM(reminder_period_key) AND NULLIF(reminder_period_key, '') IS NOT NULL) OR (reminder_type IN ('7_day', '1_day') AND reminder_period_key IS NULL)",
                         name: 'event_reminder_logs_type_period_key_match'
  end
end
