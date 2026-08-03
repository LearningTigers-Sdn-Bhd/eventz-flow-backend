FactoryBot.define do
  factory :exhibitor_booth do
    event
    exhibitor_booth_price { association :exhibitor_booth_price, event: event }
    sequence(:number) { |n| format('S%03d', n) }
    status { :available }
  end
end
