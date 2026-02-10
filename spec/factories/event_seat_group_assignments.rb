FactoryBot.define do
  factory :event_seat_group_assignment do
    association :event_seat_group
    association :event_ticket_seat
  end
end
