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

    it 'creates a paid exhibitor ticket and links it when added to a ticket event kit' do
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
                                   .and have_enqueued_mail(TicketMailer, :confirmation_email)

      member.reload
      ticket = member.attendee

      expect(ticket).to be_a(Ticket)
      expect(ticket.ticket_type.name).to eq('Exhibitor')
      expect(ticket.ticket_type.event).to eq(event)
      expect(ticket.role).to eq('Exhibitor')
      expect(ticket.attendee_name).to eq('Jane Expo')
      expect(ticket.attendee_email).to eq('jane@example.com')
      expect(ticket.attendee_phone).to eq('+60123456789')
      expect(ticket.payment_status).to eq('paid')
      expect(ticket.status).to eq('purchased')
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

    context 'when a team member limit with extra fee is configured' do
      let!(:team_member_limit) do
        create(:exhibitor_team_member_limit, event: event, team_member_limit: 3, extra_team_member_fee: 50.00)
      end

      # exhibitor_kit factory creates 2 members already

      it 'creates a paid ticket for a member within the free limit' do
        member = nil

        expect do
          member = create(
            :exhibitor_team_member,
            exhibitor_kit: exhibitor_kit,
            full_name: 'Within Limit',
            email: 'within@example.com',
            phone: '+60333333333'
          )
        end.to have_enqueued_mail(TicketMailer, :confirmation_email)

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
        end.not_to have_enqueued_mail(TicketMailer, :confirmation_email)

        ticket = excess_member.reload.attendee
        expect(ticket).to be_a(Ticket)
        expect(ticket.status).to eq('pending_payment')
        expect(ticket.payment_status).to eq('pending')
      end
    end
  end
end
