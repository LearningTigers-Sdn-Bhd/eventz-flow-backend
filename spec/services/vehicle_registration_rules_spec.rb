require 'rails_helper'

RSpec.describe VehicleRegistrationRules do
  it 'allows Support - Corporate as a base ticket for competitor-support, with no included free seat' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'competitor-support')
    corporate = create(:ticket_type, event: event, name: 'Support - Corporate', status: :published, hidden: false)
    create(:registration_form_ticket_type, registration_form: form, ticket_type: corporate)

    rules = described_class.new(form)

    expect(rules.allowed_ticket_names(nil)).to include('Support - Corporate')
  end

  it 'offers the free included seat and a paid non-member seat for competitor-support 2nd person' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'competitor-support')
    member = create(:ticket_type, event: event, name: 'Support - Member', status: :published, hidden: false)
    included = create(:ticket_type, event: event, name: 'Included 2nd Person - Member/Corporate', status: :published,
                                     hidden: false)
    non_member = create(:ticket_type, event: event, name: 'Additional Person - Non-Member', status: :published,
                                       hidden: false)
    [member, included, non_member].each do |ticket_type|
      create(:registration_form_ticket_type, registration_form: form, ticket_type: ticket_type)
    end

    vehicle_registration = VehicleRegistration.create!(
      event: event, registration_form: form, base_ticket_type: member,
      plate: 'ABC1234', normalized_plate: VehicleRegistration.normalize_plate('ABC1234')
    )
    create(:ticket, event: event, ticket_type: member, vehicle_registration: vehicle_registration)

    rules = described_class.new(form)

    expect(rules.allowed_ticket_names(vehicle_registration)).to contain_exactly(
      'Included 2nd Person - Member/Corporate', 'Additional Person - Non-Member'
    )
  end

  it 'offers the free included seat and a paid non-member seat for expedition 2nd person' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'expedition-a-tags-on')
    member = create(:ticket_type, event: event, name: 'Expedition - Member', status: :published, hidden: false)
    included = create(:ticket_type, event: event, name: 'Included 2nd Person - Member/Corporate', status: :published,
                                     hidden: false)
    non_member = create(:ticket_type, event: event, name: 'Additional Person - Non-Member', status: :published,
                                       hidden: false)
    [member, included, non_member].each do |ticket_type|
      create(:registration_form_ticket_type, registration_form: form, ticket_type: ticket_type)
    end

    vehicle_registration = VehicleRegistration.create!(
      event: event, registration_form: form, base_ticket_type: member,
      plate: 'ABC1234', normalized_plate: VehicleRegistration.normalize_plate('ABC1234')
    )
    create(:ticket, event: event, ticket_type: member, vehicle_registration: vehicle_registration)

    rules = described_class.new(form)

    expect(rules.allowed_ticket_names(vehicle_registration)).to contain_exactly(
      'Included 2nd Person - Member/Corporate', 'Additional Person - Non-Member'
    )
  end

  it 'qualifies Support - Corporate for the free included seat like Support - Member' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'competitor-support')
    corporate = create(:ticket_type, event: event, name: 'Support - Corporate', status: :published, hidden: false)
    included = create(:ticket_type, event: event, name: 'Included 2nd Person - Member/Corporate', status: :published,
                                     hidden: false)
    non_member = create(:ticket_type, event: event, name: 'Additional Person - Non-Member', status: :published,
                                       hidden: false)
    [corporate, included, non_member].each do |ticket_type|
      create(:registration_form_ticket_type, registration_form: form, ticket_type: ticket_type)
    end

    vehicle_registration = VehicleRegistration.create!(
      event: event, registration_form: form, base_ticket_type: corporate,
      plate: 'ABC1234', normalized_plate: VehicleRegistration.normalize_plate('ABC1234')
    )
    create(:ticket, event: event, ticket_type: corporate, vehicle_registration: vehicle_registration)

    rules = described_class.new(form)

    expect(rules.allowed_ticket_names(vehicle_registration)).to contain_exactly(
      'Included 2nd Person - Member/Corporate', 'Additional Person - Non-Member'
    )
  end

  it 'keeps offering the free seat to the 3rd person if the 2nd person skipped it' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'expedition-a-tags-on')
    member = create(:ticket_type, event: event, name: 'Expedition - Member', status: :published, hidden: false)
    included = create(:ticket_type, event: event, name: 'Included 2nd Person - Member/Corporate', status: :published,
                                     hidden: false)
    additional_member = create(:ticket_type, event: event, name: 'Additional Person - Member', status: :published,
                                               hidden: false)
    non_member = create(:ticket_type, event: event, name: 'Additional Person - Non-Member', status: :published,
                                       hidden: false)
    [member, included, additional_member, non_member].each do |ticket_type|
      create(:registration_form_ticket_type, registration_form: form, ticket_type: ticket_type)
    end

    vehicle_registration = VehicleRegistration.create!(
      event: event, registration_form: form, base_ticket_type: member,
      plate: 'ABC1234', normalized_plate: VehicleRegistration.normalize_plate('ABC1234')
    )
    create(:ticket, event: event, ticket_type: member, vehicle_registration: vehicle_registration)
    create(:ticket, event: event, ticket_type: non_member, vehicle_registration: vehicle_registration)

    rules = described_class.new(form)

    expect(rules.allowed_ticket_names(vehicle_registration)).to contain_exactly(
      'Included 2nd Person - Member/Corporate', 'Additional Person - Non-Member'
    )
  end

  it 'stops offering the free seat once someone has claimed it' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'expedition-a-tags-on')
    member = create(:ticket_type, event: event, name: 'Expedition - Member', status: :published, hidden: false)
    included = create(:ticket_type, event: event, name: 'Included 2nd Person - Member/Corporate', status: :published,
                                     hidden: false)
    additional_member = create(:ticket_type, event: event, name: 'Additional Person - Member', status: :published,
                                               hidden: false)
    non_member = create(:ticket_type, event: event, name: 'Additional Person - Non-Member', status: :published,
                                       hidden: false)
    [member, included, additional_member, non_member].each do |ticket_type|
      create(:registration_form_ticket_type, registration_form: form, ticket_type: ticket_type)
    end

    vehicle_registration = VehicleRegistration.create!(
      event: event, registration_form: form, base_ticket_type: member,
      plate: 'ABC1234', normalized_plate: VehicleRegistration.normalize_plate('ABC1234')
    )
    create(:ticket, event: event, ticket_type: member, vehicle_registration: vehicle_registration)
    create(:ticket, event: event, ticket_type: included, vehicle_registration: vehicle_registration)

    rules = described_class.new(form)

    expect(rules.allowed_ticket_names(vehicle_registration)).to contain_exactly(
      'Additional Person - Member', 'Additional Person - Non-Member'
    )
  end
end
