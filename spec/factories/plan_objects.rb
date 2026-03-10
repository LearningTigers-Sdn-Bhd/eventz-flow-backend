FactoryBot.define do
  factory :plan_object do
    association :plan
    object_type { :table }
    layer { "furniture" }
    x { 100.0 }
    y { 100.0 }
    rotation { 0.0 }
    width { 60.0 }
    height { 60.0 }
    label { "Table 1" }
    capacity { 10 }
    locked { false }
    z_index { 1 }

    trait :table do
      object_type { :table }
      capacity { 10 }
    end

    trait :wall do
      object_type { :wall }
      capacity { nil }
    end
  end
end