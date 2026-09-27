require 'rails_helper'

RSpec.describe VehicleRegistrationAudit do
  let(:event) { create(:event, status: :published, vehicles_enabled: true) }

  let(:expedition_form) do
    create(:registration_form, event: event, slug: 'expedition-tags-on', name: 'Expedition (Tags-on)')
  end
  let(:expedition_a_form) do
    create(:registration_form, event: event, slug: 'expedition-a-tags-on', name: 'Expedition A (Tags-on)')
  end
  let(:support_form) do
    create(:registration_form, event: event, slug: 'competitor-support', name: 'Competitor Support')
  end

  let!(:expedition_member) { ticket_type('Expedition - Member', 800, expedition_form) }
  let!(:expedition_a_member) { ticket_type('Expedition - Member', 800, expedition_a_form) }
  let!(:additional_member) { ticket_type('Additional Person - Member', 400, expedition_form) }
  let!(:support_member) { ticket_type('Support - Member', 800, support_form) }
  let!(:support_additional_member) { ticket_type('Additional Person - Member', 400, support_form) }

  def ticket_type(name, price, form)
    value = create(:ticket_type, event: event, name: name, price: price, status: :published, hidden: false)
    create(:registration_form_ticket_type, registration_form: form, ticket_type: value)
    value
  end

  def vehicle(plate:, form:, base:)
    VehicleRegistration.create!(
      event: event,
      registration_form: form,
      base_ticket_type: base,
      plate: plate,
      normalized_plate: VehicleRegistration.normalize_plate(plate)
    )
  end

  def crew(vehicle:, ticket_type:, name:, role: 'Passenger', status: :purchased)
    create(:ticket,
           event: event,
           ticket_type: ticket_type,
           vehicle_registration: vehicle,
           attendee_name: name,
           role: role,
           status: status)
  end

  def codes(result)
    result.map(&:code)
  end

  context 'with a consistent car' do
    it 'returns no issues' do
      car = vehicle(plate: 'SAA 1000', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      crew(vehicle: car, ticket_type: additional_member, name: 'Passenger One')

      expect(described_class.call(car)).to eq([])
    end
  end

  context 'when the registrant holds the base ticket but is not labelled Driver' do
    it 'does not flag the car (no false positive)' do
      # The person who registered the car holds the base ticket but kept the
      # default role; their co-crew member is the labelled Driver on an
      # additional ticket. This must not be flagged.
      car = vehicle(plate: 'SAA 1001', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Registrant', role: 'Passenger')
      crew(vehicle: car, ticket_type: additional_member, name: 'Actual Driver', role: 'Driver')

      expect(described_class.call(car)).to eq([])
    end
  end

  context 'wrong_group' do
    it 'flags a car whose driver holds a base ticket of another group' do
      car = vehicle(plate: 'SAA 1002', form: support_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      result = described_class.call(car)
      expect(codes(result)).to include(:wrong_group)
    end

    it 'uses the first crew member when nobody is labelled Driver' do
      car = vehicle(plate: 'SAA 1003', form: support_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Registrant', role: 'Passenger')

      result = described_class.call(car)
      expect(codes(result)).to include(:wrong_group)
    end
  end

  context 'stale_base' do
    it 'flags when base_ticket_type differs from the base ticket the crew holds' do
      car = vehicle(plate: 'SAA 1004', form: expedition_form, base: expedition_a_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      result = described_class.call(car)
      expect(codes(result)).to include(:stale_base)
    end

    it 'compares against the base holder, not the Driver role' do
      # Base holder is the registrant (Passenger role); the labelled Driver has
      # an additional ticket. Base matches the holder, so nothing is flagged.
      car = vehicle(plate: 'SAA 1005', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Registrant', role: 'Passenger')
      crew(vehicle: car, ticket_type: additional_member, name: 'Driver One', role: 'Driver')

      expect(described_class.call(car)).to eq([])
    end
  end

  context 'no_base_holder' do
    it 'flags a car whose active crew holds no base ticket' do
      car = vehicle(plate: 'SAA 1006', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: additional_member, name: 'Passenger One')

      result = described_class.call(car)
      expect(codes(result)).to include(:no_base_holder)
    end

    it 'ignores canceled and refunded crew' do
      car = vehicle(plate: 'SAA 1007', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Gone Driver', role: 'Driver', status: :canceled)
      crew(vehicle: car, ticket_type: additional_member, name: 'Passenger One')

      result = described_class.call(car)
      expect(codes(result)).to include(:no_base_holder)
    end
  end

  context 'ticket_not_in_group' do
    it 'flags crew whose ticket type is not offered by the car group' do
      car = vehicle(plate: 'SAA 1008', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      stray = crew(vehicle: car, ticket_type: support_additional_member, name: 'Stray Passenger')

      result = described_class.call(car)
      issue = result.find { |i| i.code == :ticket_not_in_group }
      expect(issue).not_to be_nil
      expect(issue.ticket_id).to eq(stray.id)
    end
  end

  context 'unsupported_form' do
    it 'flags a car whose group has no vehicle rules' do
      plain_form = create(:registration_form, event: event, slug: 'conference', name: 'Conference')
      plain_type = ticket_type('Conference Pass', 100, plain_form)
      car = vehicle(plate: 'SAA 1009', form: plain_form, base: plain_type)
      crew(vehicle: car, ticket_type: plain_type, name: 'Driver One', role: 'Driver')

      result = described_class.call(car)
      expect(codes(result)).to include(:unsupported_form)
    end
  end

  context 'with an empty car' do
    it 'returns no issues' do
      car = vehicle(plate: 'SAA 1010', form: expedition_form, base: expedition_member)
      expect(described_class.call(car)).to eq([])
    end
  end

  context 'with several main-vehicle ticket holders' do
    let(:crew_form) { create(:registration_form, event: event, slug: 'official-crew', name: 'Official Crew') }
    let(:competition_form) { create(:registration_form, event: event, slug: 'competition', name: 'Competition') }

    it 'accepts them in Official Crew, where extra seats use the base names' do
      crew_member = ticket_type('Official Crew - Member', 0, crew_form)
      crew_non_member = ticket_type('Official Crew - Non-Member', 0, crew_form)
      car = vehicle(plate: 'KKM 003', form: crew_form, base: crew_non_member)
      driver = crew(vehicle: car, ticket_type: crew_member, name: 'Driver', role: 'Driver')
      crew(vehicle: car, ticket_type: crew_non_member, name: 'Passenger')

      audit = described_class.new(car)
      expect(audit.ambiguous_base?).to be(false)
      expect(audit.base_holder).to eq(driver)
      expect(codes(audit.call)).to eq([:stale_base])
    end

    it 'flags two main tickets in a Competition car' do
      member = ticket_type('Competition - Member', 800, competition_form)
      car = vehicle(plate: 'PCK 7823', form: competition_form, base: member)
      crew(vehicle: car, ticket_type: member, name: 'Driver', role: 'Driver')
      crew(vehicle: car, ticket_type: member, name: 'Co', role: 'Co-Driver')

      expect(codes(described_class.call(car))).to eq([:multiple_base_holders])
    end
  end
end
