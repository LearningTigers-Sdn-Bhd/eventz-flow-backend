FactoryBot.define do
  factory :registration_form_ticket_type do
    registration_form
    ticket_type
    registration_mode { :single }
    min_attendees { 1 }
    max_attendees { nil }
  end
end
