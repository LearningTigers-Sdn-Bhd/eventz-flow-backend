FactoryBot.define do
  factory :event do
    title { "MyString" }
    description { "MyText" }
    start_date { "2025-10-13 12:03:33" }
    end_date { "2025-10-13 12:03:33" }
    location { "MyString" }
    user { nil }
  end
end
