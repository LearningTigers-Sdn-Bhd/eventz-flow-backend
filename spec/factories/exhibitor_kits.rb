FactoryBot.define do
  factory :exhibitor_kit do
    event_vendor { association :exhibitor }

    booth_number { 'A123' }
    booth_type { 'shell_scheme' }
    name_on_fascia { 'Test Company Fascia' }
    company_name { 'Test Company Pte Ltd' }
    company_address { Faker::Address.full_address }
    pic_full_name { Faker::Name.name }
    pic_contact_number { Faker::PhoneNumber.phone_number }
    pic_email_address { Faker::Internet.email }
    indemnity_signed { Faker::Boolean.boolean }

    # Optional attributes
    booth_dimensions { "#{Faker::Number.between(from: 1, to: 10)}x#{Faker::Number.between(from: 1, to: 10)}" }
    side_wall_left_required { Faker::Boolean.boolean }
    side_wall_right_required { Faker::Boolean.boolean }
    fascia_upgrade_required { Faker::Boolean.boolean }
    special_requirements { Faker::Lorem.sentence }
    digital_brochure_link { Faker::Internet.url }
    qr_code_url { SecureRandom.uuid } # Will be overridden by model callback
    indemnity_document_url { Faker::Internet.url }

    # Ensure exhibitor_kit_id is set for exhibitor_team_members
    after(:create) do |exhibitor_kit|
      create_list(:exhibitor_team_member, 2, exhibitor_kit: exhibitor_kit)
    end
  end
end
