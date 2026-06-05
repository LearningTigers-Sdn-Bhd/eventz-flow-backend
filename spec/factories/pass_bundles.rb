FactoryBot.define do
  factory :pass_bundle do
    event
    registration_form { association :registration_form, event: event }
    ticket_type { association :ticket_type, event: event }
    name { 'STB' }
    pass_limit { 10 }
    payment_mode { :free }
    payment_status { :not_required }
    status { :active }
  end
end
