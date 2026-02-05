FactoryBot.define do
  factory :event_reminder_log do
    event
    ticket
    reminder_type { "7_day" }
    status { "sent" }
    sent_at { Time.current }
  end
end
