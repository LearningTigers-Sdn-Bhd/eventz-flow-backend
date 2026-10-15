require 'rails_helper'

RSpec.describe PassBundle, type: :model do
  let(:event) { create(:event) }
  let(:registration_form) { create(:registration_form, event: event, slug: 'delegate') }
  let(:ticket_type) { create(:ticket_type, event: event, status: :published, hidden: false) }

  describe 'defaults' do
    it 'generates a token and defaults payment status for free bundles' do
      bundle = described_class.create!(
        event: event,
        registration_form: registration_form,
        ticket_type: ticket_type,
        name: 'STB',
        pass_limit: 10,
        payment_mode: :free,
        status: :active
      )

      expect(bundle.token).to be_present
      expect(bundle.payment_status).to eq('not_required')
      expect(bundle.used_count).to eq(0)
      expect(bundle.remaining_count).to eq(10)
    end

    it 'defaults payment status for offline-paid bundles' do
      bundle = described_class.create!(
        event: event,
        registration_form: registration_form,
        ticket_type: ticket_type,
        name: 'Microsoft',
        pass_limit: 10,
        payment_mode: :pay_offline,
        status: :active
      )

      expect(bundle.payment_status).to eq('unpaid')
    end
  end

  describe 'validation' do
    it 'requires the registration form to belong to the event' do
      other_event = create(:event)
      other_form = create(:registration_form, event: other_event, slug: 'other')

      bundle = described_class.new(
        event: event,
        registration_form: other_form,
        ticket_type: ticket_type,
        name: 'SCC',
        pass_limit: 10,
        payment_mode: :free,
        payment_status: :not_required,
        status: :active
      )

      expect(bundle).not_to be_valid
      expect(bundle.errors[:registration_form]).to include('must belong to the same event')
    end

    it 'requires the ticket type to belong to the event' do
      other_event = create(:event)
      other_ticket_type = create(:ticket_type, event: other_event)

      bundle = described_class.new(
        event: event,
        registration_form: registration_form,
        ticket_type: other_ticket_type,
        name: 'SabahNet',
        pass_limit: 10,
        payment_mode: :free,
        payment_status: :not_required,
        status: :active
      )

      expect(bundle).not_to be_valid
      expect(bundle.errors[:ticket_type]).to include('must belong to the same event')
    end

    it 'does not allow pass_limit below used_count' do
      bundle = create(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, pass_limit: 2)
      create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: bundle)
      create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: bundle)

      bundle.pass_limit = 1

      expect(bundle).not_to be_valid
      expect(bundle.errors[:pass_limit]).to include('cannot be lower than used passes')
    end

    it 'allows a table plan_object to be linked' do
      plan = create(:plan, event: event)
      table = create(:plan_object, :table, plan: plan)

      bundle = build(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, plan_object: table)

      expect(bundle).to be_valid
    end

    it 'rejects a non-table plan_object' do
      plan = create(:plan, event: event)
      wall = create(:plan_object, :wall, plan: plan)

      bundle = build(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, plan_object: wall)

      expect(bundle).not_to be_valid
      expect(bundle.errors[:plan_object]).to include('must be a table')
    end
  end

  describe '#accepting_registrations?' do
    it 'returns false when paused, expired, or full' do
      active_bundle = create(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, pass_limit: 1)
      paused_bundle = create(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, status: :paused)
      expired_bundle = create(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, expires_at: 1.day.ago)

      create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: active_bundle)

      expect(active_bundle.accepting_registrations?).to be(false)
      expect(paused_bundle.accepting_registrations?).to be(false)
      expect(expired_bundle.accepting_registrations?).to be(false)
    end
  end
end
