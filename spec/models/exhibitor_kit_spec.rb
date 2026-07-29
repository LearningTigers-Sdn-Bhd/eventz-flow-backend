require 'rails_helper'

RSpec.describe ExhibitorKit, type: :model do
  it 'generates a short public id for new kits' do
    kit = build(:exhibitor_kit)

    expect(kit).to be_valid
    expect(kit.public_id).to match(/\A[1-9A-HJ-NP-Za-km-z]{22}\z/)
  end
  include ActiveJob::TestHelper
  let(:event) { create(:event, use_ticket: true) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }

  subject { build(:exhibitor_kit, event_vendor: exhibitor) }

  it { should belong_to(:event_vendor).inverse_of(:exhibitor_kits) }
  it { should have_many(:exhibitor_team_members).dependent(:destroy) }
  it { should validate_presence_of(:booth_type) }

  it { should validate_length_of(:name_on_fascia).is_at_most(30) }

  it { should validate_presence_of(:pic_full_name) }
  it { should validate_presence_of(:pic_contact_number) }

  it do
    should define_enum_for(:booking_status)
      .with_values(active: 0, paid: 1, cancelled: 2, expired: 3)
      .with_prefix(:booking)
  end

  it { should validate_uniqueness_of(:public_id).ignoring_case_sensitivity }
  it { should validate_uniqueness_of(:idempotency_key).scoped_to(:event_vendor_id).allow_nil }

  it 'allows multiple legacy rows without idempotency keys' do
    create(:exhibitor_kit, event_vendor: exhibitor, idempotency_key: nil)

    expect(build(:exhibitor_kit, event_vendor: exhibitor, idempotency_key: nil)).to be_valid
  end

  it 'allows the same idempotency key for different exhibitors' do
    create(:exhibitor_kit, event_vendor: exhibitor, idempotency_key: 'registration-1')
    other_exhibitor = create(:exhibitor)

    expect(build(:exhibitor_kit, event_vendor: other_exhibitor, idempotency_key: 'registration-1')).to be_valid
  end

  it 'generates a short public id and lifecycle defaults' do
    exhibitor_kit = create(:exhibitor_kit, event_vendor: exhibitor)

    expect(exhibitor_kit.public_id).to match(/\A[1-9A-HJ-NP-Za-km-z]{22}\z/)
    expect(exhibitor_kit).to be_booking_active
    expect(exhibitor_kit.price_snapshot).to eq(0)
    expect(exhibitor_kit.currency).to eq('MYR')
    expect(exhibitor_kit.lock_version).to eq(0)
    expect(exhibitor_kit.reservation_expires_at).to be_nil
  end

  it { should allow_value('test@example.com').for(:pic_email_address) }
  it { should_not allow_value('invalid-email').for(:pic_email_address) }

  describe 'nested attributes for exhibitor_team_members' do
    it 'accepts nested attributes for exhibitor_team_members' do
      exhibitor_kit = create(
        :exhibitor_kit,
        event_vendor: exhibitor,
        exhibitor_team_members_attributes: [{ full_name: 'John Doe', email: 'john@example.com', phone: '+60123456789' }]
      )

      expect(exhibitor_kit.exhibitor_team_members.first.full_name).to eq('John Doe')
    end

    it 'destroys exhibitor_team_members' do
      exhibitor_kit = create(:exhibitor_kit, event_vendor: exhibitor)

      member = create(
        :exhibitor_team_member,
        exhibitor_kit: exhibitor_kit,
        email: 'member@example.com',
        phone: '+60123456789'
      )

      expect do
        exhibitor_kit.update(exhibitor_team_members_attributes: [{ id: member.id, _destroy: '1' }])
      end.to change(ExhibitorTeamMember, :count).by(-1)
    end

    it 'deletes the linked ticket when a team member is destroyed through nested attributes' do
      exhibitor_kit = create(:exhibitor_kit, event_vendor: exhibitor)
      member = create(
        :exhibitor_team_member,
        exhibitor_kit: exhibitor_kit,
        email: 'member@example.com',
        phone: '+60123456789'
      )
      ticket_id = member.attendee_id

      expect do
        exhibitor_kit.update(exhibitor_team_members_attributes: [{ id: member.id, _destroy: '1' }])
      end.to change(Ticket.unscoped, :count).by(-1)

      expect(Ticket.unscoped.find_by(id: ticket_id)).to be_nil
    end
  end

  describe 'team member limit methods' do
    let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

    context 'when event has no limit configured' do
      it 'returns nil for team_member_limit' do
        expect(exhibitor_kit.team_member_limit).to be_nil
      end

      it 'returns false for has_team_member_limit?' do
        expect(exhibitor_kit.has_team_member_limit?).to be false
      end

      it 'returns 0 for excess_team_member_count' do
        create_list(:exhibitor_team_member, 5, exhibitor_kit: exhibitor_kit)
        expect(exhibitor_kit.excess_team_member_count).to eq(0)
      end
    end

    context 'when event has a limit configured' do
      before do
        create(:exhibitor_team_member_limit, event: event, team_member_limit: 3, extra_team_member_fee: 50.00)
      end

      it 'returns the limit from event settings' do
        expect(exhibitor_kit.team_member_limit).to eq(3)
      end

      it 'returns true for has_team_member_limit?' do
        expect(exhibitor_kit.has_team_member_limit?).to be true
      end

      context 'with team members within limit' do
        # NOTE: exhibitor_kit factory creates 2 members by default
        # Limit is 3, so with 2 members we are within limit

        it 'returns 0 for excess_team_member_count' do
          expect(exhibitor_kit.excess_team_member_count).to eq(0)
        end

        it 'returns false for has_unpaid_excess_team_members?' do
          expect(exhibitor_kit.has_unpaid_excess_team_members?).to be false
        end

        it 'returns 0 for extra_team_member_charges' do
          expect(exhibitor_kit.extra_team_member_charges).to eq(0)
        end
      end

      context 'with team members exceeding limit' do
        # NOTE: exhibitor_kit factory creates 2 members by default
        # Adding 3 more = 5 total, limit is 3 → 2 excess
        before do
          create_list(:exhibitor_team_member, 3, exhibitor_kit: exhibitor_kit)
        end

        it 'returns the excess count' do
          # 2 (factory default) + 3 (added) = 5 total, limit 3 → 2 excess
          expect(exhibitor_kit.excess_team_member_count).to eq(2)
        end

        it 'returns true for has_unpaid_excess_team_members?' do
          expect(exhibitor_kit.has_unpaid_excess_team_members?).to be true
        end

        it 'calculates extra charges correctly' do
          expect(exhibitor_kit.extra_team_member_charges).to eq(100.00) # 2 excess * 50.00
        end

        it 'reports how many paid extra slots are currently in use' do
          create(
            :exhibitor_team_member_payment,
            :verified,
            exhibitor_kit: exhibitor_kit,
            extra_member_count: 1,
            fee_per_member: 50.0,
            amount: 50.0,
            payee: create(:user)
          )

          expect(exhibitor_kit.paid_extra_member_count).to eq(1)
          expect(exhibitor_kit.used_paid_extra_member_count).to eq(1)
        end

        it 'does not count unused paid slots as in use' do
          create(
            :exhibitor_team_member_payment,
            :verified,
            exhibitor_kit: exhibitor_kit,
            extra_member_count: 3,
            fee_per_member: 50.0,
            amount: 150.0,
            payee: create(:user)
          )

          expect(exhibitor_kit.paid_extra_member_count).to eq(3)
          expect(exhibitor_kit.used_paid_extra_member_count).to eq(2)
        end
      end
    end
  end

  describe 'email callbacks' do
    before do
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
    end

    it 'enqueues registration received email on create' do
      event_vendor = create(:exhibitor, event: event, vendor: vendor_user)
      clear_enqueued_jobs

      expect do
        create(:exhibitor_kit, event_vendor: event_vendor, pic_email_address: 'new-exhibitor@example.com')
      end.to have_enqueued_job(EmailDeliveryJob)
    end

    it 'enqueues payment confirmed email when payment transitions to paid' do
      event_vendor = create(:exhibitor, event: event, vendor: vendor_user)
      clear_enqueued_jobs
      exhibitor_kit = create(:exhibitor_kit, event_vendor: event_vendor, payment_status: :unpaid)
      clear_enqueued_jobs

      expect do
        exhibitor_kit.update!(payment_status: :paid)
      end.to have_enqueued_job(EmailDeliveryJob)
        .with(
          kind_of(Integer),
          'ExhibitorRegistrationMailer',
          'payment_confirmed_email',
          kind_of(Array)
        )
    end

    it 'does not enqueue payment confirmed email when status stays paid' do
      event_vendor = create(:exhibitor, event: event, vendor: vendor_user)
      clear_enqueued_jobs
      exhibitor_kit = create(:exhibitor_kit, event_vendor: event_vendor, payment_status: :paid)
      clear_enqueued_jobs

      expect do
        exhibitor_kit.update!(company_name: 'Updated Co')
      end.not_to have_enqueued_job(EmailDeliveryJob)
    end
  end

  describe 'payment option custom field cleanup' do
    it 'removes payment_option from custom_fields_data when kit becomes paid' do
      exhibitor_kit = create(
        :exhibitor_kit,
        event_vendor: exhibitor,
        payment_status: :unpaid,
        custom_fields_data: {
          'payment_option' => 'later',
          'preferred_booth_location' => 'Near entrance'
        }
      )

      exhibitor_kit.update!(payment_status: :paid)

      expect(exhibitor_kit.reload.custom_fields_data).to eq(
        'preferred_booth_location' => 'Near entrance'
      )
    end
  end
end
