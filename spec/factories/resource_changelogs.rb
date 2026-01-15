# spec/factories/resource_changelogs.rb
FactoryBot.define do
  factory :resource_changelog do
    association :resource
    association :changed_by_user, factory: :user

    title { Faker::Lorem.sentence }
    article { Faker::Lorem.paragraph(sentence_count: 10) }
    slug { Faker::Internet.slug }
    meta_description { Faker::Lorem.sentence }
    status { 2 } # published
    published_at { Faker::Time.backward(days: 30) }
    view_counts { Faker::Number.between(from: 0, to: 1000) }
    priority { Faker::Number.between(from: 1, to: 10) }
    is_gated { false }
    is_official { false }
    rejection_reason { nil }
    changed_at { Time.current }

    # Associations for topic, category, media_type (stored as IDs)
    resource_topic_id { create(:resource_topic).id }
    resource_category_id { create(:resource_category).id }
    resource_media_type_id { create(:resource_media_type).id }
  end
end
