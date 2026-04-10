require 'rails_helper'

RSpec.describe BorneoExpoTicketUpgradeService, type: :service do
  describe '.call' do
    subject(:call_service) do
      described_class.call(event: event, attendee_email: attendee_email, target_category: target_category)
    end

    let(:attendee_email) { '  Person@Example.COM  ' }
    let(:target_category) { 'conference' }

    context 'for the Borneo Expo 2026 event' do
      let(:event) { create(:event, slug: 'borneo-expo-2026') }
      let!(:exhibitor_ticket_type) { create(:ticket_type, event: event, name: 'Premium Exhibitor Access') }
      let!(:conference_ticket_type) { create(:ticket_type, event: event, name: 'Conference Pass 2026') }
      let!(:combined_ticket_type) { create(:ticket_type, event: event, name: 'Exhibitor & Conference Bundle') }

      it 'upgrades an exhibitor-like ticket to the combined type for conference access' do
        ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :purchased
        )
        original_public_id = ticket.public_id

        expect(call_service).to eq(ticket)
        expect(ticket.reload.ticket_type).to eq(combined_ticket_type)
        expect(ticket.public_id).to eq(original_public_id)
      end

      it 'upgrades a conference-like ticket to the combined type for exhibitor access' do
        ticket = create(
          :ticket,
          event: event,
          ticket_type: conference_ticket_type,
          attendee_email: 'person@example.com',
          status: :scanned
        )

        upgraded_ticket = described_class.call(
          event: event,
          attendee_email: 'person@example.com',
          target_category: 'exhibitor'
        )

        expect(upgraded_ticket).to eq(ticket)
        expect(ticket.reload.ticket_type).to eq(combined_ticket_type)
      end

      it 'treats delegate tickets as conference-like for exhibitor upgrades' do
        delegate_ticket_type = create(:ticket_type, event: event, name: 'Delegate Admission')
        ticket = create(
          :ticket,
          event: event,
          ticket_type: delegate_ticket_type,
          attendee_email: 'person@example.com',
          status: :purchased
        )

        upgraded_ticket = described_class.call(
          event: event,
          attendee_email: 'person@example.com',
          target_category: 'exhibitor'
        )

        expect(upgraded_ticket).to eq(ticket)
        expect(ticket.reload.ticket_type).to eq(combined_ticket_type)
      end

      it 'reuses an existing combined-like ticket when the name has variation' do
        create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :purchased
        )
        varied_combined_ticket_type = create(:ticket_type, event: event, name: 'VIP Delegate + Exhibitor Bundle')
        combined_ticket = create(
          :ticket,
          event: event,
          ticket_type: varied_combined_ticket_type,
          attendee_email: 'PERSON@example.com',
          status: :purchased
        )

        expect(call_service).to eq(combined_ticket)
      end

      it 'reuses an existing combined ticket for the same normalized email' do
        create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :purchased
        )
        combined_ticket = create(
          :ticket,
          event: event,
          ticket_type: combined_ticket_type,
          attendee_email: 'PERSON@example.com',
          status: :purchased
        )

        expect(call_service).to eq(combined_ticket)
      end

      it 'ignores refunded and canceled tickets when looking for an upgrade source' do
        create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :canceled
        )
        create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :refunded
        )

        expect(call_service).to be_nil
      end

      it 'can upgrade a pending payment ticket because only canceled and refunded are excluded' do
        ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :pending_payment
        )

        expect(call_service).to eq(ticket)
        expect(ticket.reload.ticket_type).to eq(combined_ticket_type)
      end

      it 'auto-creates a canonical combined ticket type when one does not exist yet' do
        combined_ticket_type.destroy!

        ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :purchased
        )

        upgraded_ticket = call_service

        expect(upgraded_ticket).to eq(ticket)
        expect(event.ticket_types.where(name: 'Exhibitor & Conference').count).to eq(1)

        created_combined_type = event.ticket_types.find_by!(name: 'Exhibitor & Conference')
        expect(created_combined_type.hidden).to be(true)
        expect(created_combined_type.status).to eq('published')
        expect(ticket.reload.ticket_type).to eq(created_combined_type)
      end

      it 'runs for borneo expo slug variants instead of exact slug equality' do
        event.update!(slug: 'borneo-expo')

        ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :purchased
        )

        upgraded_ticket = call_service

        expect(upgraded_ticket).to eq(ticket)
        expect(ticket.reload.ticket_type).to eq(combined_ticket_type)
      end
    end

    context 'for a non-Borneo event' do
      let(:event) { create(:event, slug: 'other-event-2026') }
      let(:target_category) { 'conference' }

      it 'does not upgrade or return a matching ticket' do
        exhibitor_ticket_type = create(:ticket_type, event: event, name: 'Exhibitor')
        ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'person@example.com',
          status: :purchased
        )
        original_public_id = ticket.public_id

        expect(call_service).to be_nil
        expect(ticket.reload.ticket_type).to eq(exhibitor_ticket_type)
        expect(ticket.public_id).to eq(original_public_id)
      end
    end
  end
end
