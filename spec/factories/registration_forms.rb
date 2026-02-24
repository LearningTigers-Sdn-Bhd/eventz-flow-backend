FactoryBot.define do
  factory :registration_form do
    event
    name { "Conference" }
    slug { "conference" }
    status { 0 }
    position { 1 }
  end
end
