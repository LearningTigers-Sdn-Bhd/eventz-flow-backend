FactoryBot.define do
  factory :scan_log do
    event
    association :scannable, factory: :ticket
    scanned_at { Time.current }
    source { :staff_scan }
  end
end
