FactoryBot.define do
  factory :exhibitor_voucher do
    event
    code { ExhibitorVoucher.generate_code }
    discount_type { :percentage_off }
    discount_value { 10 }
    status { :active }

    trait :fixed_amount do
      discount_type { :fixed_amount_off }
      discount_value { 500 }
    end

    trait :flat_price do
      discount_type { :flat_price }
      discount_value { 3000 }
    end

    trait :redeemed do
      status { :redeemed }
      redeemed_at { Time.current }
      association :redeemed_by_exhibitor_kit, factory: :exhibitor_kit
    end
  end
end
