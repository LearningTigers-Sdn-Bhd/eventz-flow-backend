FactoryBot.define do
  factory :event_reminder_log do
    event
    ticket
    reminder_type { '7_day' }
    reminder_period_key { nil }
    status { 'sent' }
    sent_at { Time.current }

    trait :payment_pending_weekly do
      reminder_type { 'payment_pending_weekly' }
      reminder_period_key { '2026-W15' }
    end
  end
end
