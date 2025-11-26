FactoryBot.define do
  factory :exhibitor_kit do
    association :event_vendor, factory: :exhibitor

    booth_number { Faker::Alphanumeric.unique.alpha(number: 5) }
    booth_type { [:shell_scheme, :raw_space].sample }
    name_on_fascia { Faker::Company.name.truncate(25) }
    company_name { Faker::Company.name }
    company_address { Faker::Address.full_address }
    pic_full_name { Faker::Name.name }
    pic_contact_number { Faker::PhoneNumber.phone_number }
    pic_email_address { Faker::Internet.email }
    extra_crew_count { Faker::Number.between(from: 0, to: 10) }

    indemnity_signed { Faker::Boolean.boolean }

    # Optional attributes
    booth_dimensions { "#{Faker::Number.between(from: 1, to: 10)}x#{Faker::Number.between(from: 1, to: 10)}" }
    side_wall_left_required { Faker::Boolean.boolean }
    side_wall_right_required { Faker::Boolean.boolean }
    fascia_upgrade_required { Faker::Boolean.boolean }
    special_requirements { Faker::Lorem.sentence }
    digital_brochure_link { Faker::Internet.url }
    qr_code_url { SecureRandom.uuid } # Will be overridden by model callback
    contractor_company_name { Faker::Company.name if Faker::Boolean.boolean }
    contractor_pic_name { Faker::Name.name if Faker::Boolean.boolean }
    contractor_pic_contact { Faker::PhoneNumber.phone_number if Faker::Boolean.boolean }
    stand_design_file_url { Faker::Internet.url if Faker::Boolean.boolean }
    furniture_requests { { chairs: 2, tables: 1 }.to_json }
    electrical_requests { { sockets: 4 }.to_json }
    printing_orders { { banners: 1 }.to_json }
    indemnity_document_url { Faker::Internet.url }

    # Ensure exhibitor_kit_id is set for exhibitor_team_members
    after(:create) do |exhibitor_kit|
      create_list(:exhibitor_team_member, 2, exhibitor_kit: exhibitor_kit)
    end
  end
end
