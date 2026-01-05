# spec/factories/resources.rb
FactoryBot.define do
  factory :resource_topic do
    name { "Topic #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }
  end

  factory :resource_category do
    name { "Category #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }
  end

  factory :resource_media_type do
    name { "Media #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }
  end

  factory :resource_write_permission do
    association :user
    is_official { false }
    status { :base }
  end

  factory :resource do
    title { "Resource Title: #{Faker::Book.unique.title} #{Faker::Number.unique.number(digits: 5)}" }
    article { Faker::Lorem.paragraphs(number: 4).join("\n\n") }
    meta_description { Faker::Lorem.sentence }
    status { :draft }
    is_gated { false }
    is_official { false }

    association :user
    association :resource_topic
    association :resource_category
    association :resource_media_type
  end

  factory :resource_lead do
    email { Faker::Internet.email }
    name { Faker::Name.name }
    phone { Faker::PhoneNumber.phone_number }
    company_name { Faker::Company.name }
    state { Faker::Address.state }
    country { Faker::Address.country }
    job_title { Faker::Job.title }
  end
end
