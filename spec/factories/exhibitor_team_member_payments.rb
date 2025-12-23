FactoryBot.define do
  factory :exhibitor_team_member_payment do
    association :exhibitor_kit
    payee { nil }
    extra_member_count { 2 }
    fee_per_member { 50.00 }
    amount { 100.00 }
    status { :pending }
    payment_source { nil }
    external_ref { nil }
    note { Faker::Lorem.sentence }
    paid_at { nil }

    trait :submitted do
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
      payment_source { :manual_bank_in }
      association :payee, factory: :user
      after(:build) do |payment|
        payment.payment_proof.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
      paid_at { Time.current }
    end

    trait :rejected do
      status { :rejected }
      payment_source { :manual_bank_in }
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
