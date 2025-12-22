FactoryBot.define do
  factory :exhibitor_kit_payment do
    association :exhibitor_kit
    association :payee, factory: :user
    amount { Faker::Commerce.price(range: 10.0..1000.0) }
    status { :pending }
    payment_source { nil } # Will be set conditionally in specs or by traits
    payment_proof { nil }
    external_ref { nil }
    note { Faker::Lorem.sentence }
    paid_at { nil }

    trait :submitted_manual_bank_in do
      status { :submitted }
      payment_source { :manual_bank_in }
      after(:build) do |payment|
        payment.payment_proof.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
    end

    trait :submitted_payment_gateway do
      status { :submitted }
      payment_source { :payment_gateway }
      after(:build) do |payment|
        payment.payment_proof.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
      external_ref { Faker::Alphanumeric.alphanumeric(number: 10) }
    end

    trait :verified do
      status { :verified }
      payment_source { :payment_gateway } # Or manual_bank_in
      after(:build) do |payment|
        payment.payment_proof.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
      external_ref { Faker::Alphanumeric.alphanumeric(number: 10) }
      paid_at { Time.current }
    end

    trait :rejected do
      status { :rejected }
      payment_source { :manual_bank_in } # Or payment_gateway
      after(:build) do |payment|
        payment.payment_proof.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
    end
  end
end
