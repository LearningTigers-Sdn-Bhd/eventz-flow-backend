FactoryBot.define do
  factory :ticket_scan_log do
    ticket
    event { ticket.event }
    day_index { 1 }
    scanned_at { Time.current }
    association :scanned_by, factory: :user
  end
end
