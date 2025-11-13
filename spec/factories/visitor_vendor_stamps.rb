# spec/factories/visitor_vendor_stamps.rb

FactoryBot.define do
  factory :visitor_vendor_stamp do
    association :visitor
    association :event_vendor
  end
end
