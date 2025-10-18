# spec/factories/events.rb

FactoryBot.define do
  factory :event do
    # 1. Use Faker or dynamic values for title/description
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph(sentence_count: 2) }

    # 2. Fix Dates: Ensure end_date is *after* start_date and both are in the future
    start_date { Time.current + 1.day }
    end_date { start_date + 2.hours } # Ensure it's after start_date
    
    # 3. Fix Status: Explicitly set a valid enum value
    status { :draft } # or 0, but using the symbol is cleaner

    after(:create) do |event|
      create(:event_location, event: event, name: Faker::Address.full_address, scan_limit: 50)
    end
  end
end