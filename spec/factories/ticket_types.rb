FactoryBot.define do
  factory :ticket_type do
    # Ensures a required event is provided if not explicitly passed
    event
    name { "General Admission" }
    price { 10.00 }
    quantity { 100 }
    max_per_order { 5 }
    status { :published }
  end
end