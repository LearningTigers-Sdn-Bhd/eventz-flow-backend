require 'rails_helper'

RSpec.describe ExhibitorTeamMember, type: :model do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_ticket: true) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }
  let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

  subject { build(:exhibitor_team_member, exhibitor_kit: exhibitor_kit) }

  it { should belong_to(:exhibitor_kit) }
  it { should belong_to(:attendee).optional }
  it { should validate_presence_of(:full_name) }
  it { should validate_presence_of(:email) }
  it { should validate_presence_of(:phone) }

  describe 'ticket attendee sync' do
    before do
      ActiveJob::Base.queue_adapter = :test
      exhibitor_kit
      clear_enqueued_jobs
    end

    it 'creates a pending exhibitor ticket and does not email when exhibitor kit is unpaid' do
      member = nil

      expect do
        member = create(
          :exhibitor_team_member,
          exhibitor_kit: exhibitor_kit,
          full_name: 'Jane Expo',
          email: 'jane@example.com',
          phone: '+60123456789'
        )
      end.to change(Ticket, :count).by(1)
      expect(enqueued_jobs).to be_empty

      member.reload
      ticket = member.attendee

      expect(ticket).to be_a(Ticket)
      expect(ticket.ticket_type.name).to eq('Exhibitor')
      expect(ticket.ticket_type.event).to eq(event)
      expect(ticket.role).to eq('Exhibitor')
      expect(ticket.attendee_name).to eq('Jane Expo')
      expect(ticket.attendee_email).to eq('jane@example.com')
      expect(ticket.attendee_phone).to eq('+60123456789')
      expect(ticket.payment_status).to eq('pending')
      expect(ticket.status).to eq('pending_payment')
    end

    it 'upgrades free team member tickets and emails them when exhibitor kit becomes paid' do
      member = create(
        :exhibitor_team_member,
        exhibitor_kit: exhibitor_kit,
        full_name: 'Jane Expo',
        email: 'jane@example.com',
        phone: '+60123456789'
      )
      clear_enqueued_jobs

      expect do
        exhibitor_kit.update!(payment_status: :paid)
      end.to have_enqueued_job(EmailDeliveryJob)
        .with(
          kind_of(Integer),
          'TicketMailer',
          'confirmation_email',
          kind_of(Array)
        )
        .exactly(3).times

      ticket = member.reload.attendee
      expect(ticket.status).to eq('purchased')
      expect(ticket.payment_status).to eq('paid')
    end

    it 'reuses the exhibitor ticket type when adding multiple team members' do
      create(
        :exhibitor_team_member,
        exhibitor_kit: exhibitor_kit,
        email: 'first@example.com',
        phone: '+60111111111'
      )

      expect do
        create(
          :exhibitor_team_member,
          exhibitor_kit: exhibitor_kit,
          email: 'second@example.com',
          phone: '+60222222222'
        )
      end.not_to change(TicketType, :count)

      expect(event.ticket_types.where(name: 'Exhibitor').count).to eq(1)
    end

    it 'does not stamp conferences_included on a team member added after the exhibitor kit already exists' do
      booth_price = create(:exhibitor_booth_price, event: event, conferences_included: true)
      exhibitor_kit.update!(exhibitor_booth_price: booth_price)

      member = create(
        :exhibitor_team_member,
        exhibitor_kit: exhibitor_kit,
        full_name: 'Later Add',
        email: 'later@example.com',
        phone: '+60122222222'
      )

      expect(member.reload.attendee).to be_a(Ticket)
      expect(member.attendee.custom_fields_data).not_to have_key('conferences_included')
    end

    it 'reuses and upgrades an existing conference-like ticket for Borneo Expo booth managers' do
      event.update!(slug: 'borneo-expo-2026')
      exhibitor_kit.update!(payment_status: :paid)
      clear_enqueued_jobs

      create(:ticket_type, event: event, name: 'Conference Pass 2026')
      combined_ticket_type = create(:ticket_type, event: event, name: 'Exhibitor & Conference Bundle')
      existing_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: event.ticket_types.find_by!(name: 'Conference Pass 2026'),
        role: 'Custom Exhibitor Role',
        attendee_name: 'Jane Conference',
        attendee_email: 'jane@example.com',
        attendee_phone: '+60123456789',
        status: :purchased
      )
      original_public_id = existing_ticket.public_id
      clear_enqueued_jobs

      clear_enqueued_jobs
      existing_ticket_count = Ticket.count

      expect do
        @member = create(
          :exhibitor_team_member,
          exhibitor_kit: exhibitor_kit,
          full_name: 'Jane Expo',
          email: 'jane@example.com',
          phone: '+60123456789'
        )
      end.to have_enqueued_job(EmailDeliveryJob)

      expect(Ticket.count).to eq(existing_ticket_count)

      ticket = @member.reload.attendee
      expect(ticket.id).to eq(existing_ticket.id)
      expect(ticket.public_id).to eq(original_public_id)
      expect(ticket.ticket_type).to eq(combined_ticket_type)
      expect(ticket.role).to eq('Custom Exhibitor Role')
      expect(ticket.status).to eq('purchased')
      expect(ticket.payment_status).to eq('paid')
    end

    it 'does not destroy a reused combined ticket when the team member is deleted' do
      event.update!(slug: 'borneo-expo-2026')
      exhibitor_kit.update!(payment_status: :paid)

      create(:ticket_type, event: event, name: 'Conference Pass 2026')
      combined_ticket_type = create(:ticket_type, event: event, name: 'Exhibitor & Conference Bundle')
      existing_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: event.ticket_types.find_by!(name: 'Conference Pass 2026'),
        attendee_name: 'Jane Conference',
        attendee_email: 'jane@example.com',
        attendee_phone: '+60123456789',
        status: :purchased
      )

      member = create(
        :exhibitor_team_member,
        exhibitor_kit: exhibitor_kit,
        full_name: 'Jane Expo',
        email: 'jane@example.com',
        phone: '+60123456789'
      )

      expect(member.reload.attendee).to eq(existing_ticket)

      expect do
        member.destroy!
      end.not_to change(Ticket, :count)

      expect(existing_ticket.reload.ticket_type).to eq(combined_ticket_type)
    end

    context 'when a team member limit with extra fee is configured' do
      let!(:team_member_limit) do
        create(:exhibitor_team_member_limit, event: event, team_member_limit: 3, extra_team_member_fee: 50.00)
      end

      # exhibitor_kit factory creates 2 members already

      it 'creates a paid ticket for a member within the free limit' do
        exhibitor_kit.update!(payment_status: :paid)
        clear_enqueued_jobs
        member = nil

        expect do
          member = create(
            :exhibitor_team_member,
            exhibitor_kit: exhibitor_kit,
            full_name: 'Within Limit',
            email: 'within@example.com',
            phone: '+60333333333'
          )
        end.to have_enqueued_job(EmailDeliveryJob)

        ticket = member.reload.attendee
        expect(ticket.status).to eq('purchased')
        expect(ticket.payment_status).to eq('paid')
      end

      it 'creates a pending ticket for an excess member and does NOT send email' do
        # 3rd member hits the limit exactly; 4th is excess
        create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit, email: 'third@example.com', phone: '+60333333333')
        clear_enqueued_jobs

        excess_member = nil

        expect do
          excess_member = create(
            :exhibitor_team_member,
            exhibitor_kit: exhibitor_kit,
            full_name: 'Excess Member',
            email: 'excess@example.com',
            phone: '+60444444444'
          )
        end.not_to have_enqueued_job(EmailDeliveryJob)

        ticket = excess_member.reload.attendee
        expect(ticket).to be_a(Ticket)
        expect(ticket.status).to eq('pending_payment')
        expect(ticket.payment_status).to eq('pending')
      end

      it 'reuses a paid extra slot when a paid excess member is deleted and replaced' do
        exhibitor_kit.update!(payment_status: :paid)
        create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit, email: 'third@example.com', phone: '+60333333333')
        paid_excess_member = create(
          :exhibitor_team_member,
          exhibitor_kit: exhibitor_kit,
          full_name: 'Paid Excess',
          email: 'paid.excess@example.com',
          phone: '+60444444444'
        )

        create(
          :exhibitor_team_member_payment,
          :verified,
          exhibitor_kit: exhibitor_kit,
          extra_member_count: 1,
          fee_per_member: 50.0,
          amount: 50.0,
          payee: create(:user)
        )

        paid_excess_ticket = paid_excess_member.reload.attendee
        expect(paid_excess_ticket.status).to eq('purchased')
        expect(paid_excess_ticket.payment_status).to eq('paid')

        paid_excess_member.destroy!
        expect(Ticket.unscoped.find_by(id: paid_excess_ticket.id)).to be_nil

        replacement_member = create(
          :exhibitor_team_member,
          exhibitor_kit: exhibitor_kit,
          full_name: 'Replacement Excess',
          email: 'replacement.excess@example.com',
          phone: '+60555555555'
        )

        replacement_ticket = replacement_member.reload.attendee
        expect(replacement_ticket.status).to eq('purchased')
        expect(replacement_ticket.payment_status).to eq('paid')
        expect(exhibitor_kit.reload.paid_extra_member_count).to eq(1)
      end

      it 'rebalances an excess member into a free slot when a free member is deleted' do
        exhibitor_kit.update!(payment_status: :paid)
        free_member = create(
          :exhibitor_team_member,
          exhibitor_kit: exhibitor_kit,
          full_name: 'Free Member',
          email: 'free.member@example.com',
          phone: '+60333333333'
        )
        excess_member = create(
          :exhibitor_team_member,
          exhibitor_kit: exhibitor_kit,
          full_name: 'Excess Member',
          email: 'excess.member@example.com',
          phone: '+60444444444'
        )

        excess_ticket = excess_member.reload.attendee
        expect(excess_ticket.status).to eq('pending_payment')
        expect(excess_ticket.payment_status).to eq('pending')

        free_member.destroy!

        excess_ticket.reload
        expect(excess_ticket.status).to eq('purchased')
        expect(excess_ticket.payment_status).to eq('paid')
      end
    end
  end
end
