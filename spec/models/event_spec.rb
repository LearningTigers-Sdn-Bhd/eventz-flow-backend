require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'associations' do
    it { should have_many(:event_assignments).dependent(:destroy) }
    it { should have_many(:staff).through(:event_assignments) }
    it { should have_many(:business_host_assignments).dependent(:destroy) }
    it { should have_many(:event_locations).dependent(:destroy) }
    it { should have_many(:ticket_types).dependent(:destroy) }
    it { should have_many(:tickets).dependent(:destroy) }
    it { should have_many(:event_vendors).dependent(:destroy) }
    it { should have_many(:visitors).dependent(:destroy) }
    it { should have_many(:vouchers).dependent(:destroy) }
    it { should have_many(:event_exhibition_contractors).dependent(:destroy) }
    it { should have_many(:event_printing_services).dependent(:destroy) }
    it { should have_many(:event_rentable_items).dependent(:destroy) }
    it { should have_many(:lucky_draw_sessions).dependent(:destroy) }
    it { should have_one(:exhibitor_team_member_limit).dependent(:destroy) }
    it { should have_many(:event_sponsorship_tiers).dependent(:destroy) }
    it { should have_many(:event_sponsorships).dependent(:destroy) }
    it { should have_many(:sponsors).through(:event_sponsorships) }
  end

  describe 'attributes' do
    it 'has use_sponsorship defaulting to false' do
      expect(Event.new.use_sponsorship).to be false
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(100) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }

    describe 'end_date validation' do
      it 'is invalid when end_date is before start_date' do
        event = build(:event, start_date: Time.current + 2.days, end_date: Time.current + 1.day)
        expect(event).not_to be_valid
        expect(event.errors[:end_date]).to include('must be after the start date')
      end

      it 'is valid when end_date is after start_date' do
        event = build(:event, start_date: Time.current + 1.day, end_date: Time.current + 2.days)
        expect(event).to be_valid
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(draft: 0, published: 1, cancelled: 2, completed: 3) }
    it { should define_enum_for(:payment_status).with_values(unpaid: 0, paid: 1, waived: 2) }
  end

  describe 'soft delete scopes' do
    let!(:active_event) { create(:event) }
    let!(:deleted_event) { create(:event).tap { |e| e.update_column(:deleted_at, Time.current) } }

    describe 'default_scope' do
      it 'excludes soft-deleted events' do
        expect(Event.all).to include(active_event)
        expect(Event.all).not_to include(deleted_event)
      end
    end

    describe '.with_deleted' do
      it 'includes soft-deleted events' do
        expect(Event.with_deleted).to include(active_event)
        expect(Event.with_deleted).to include(deleted_event)
      end
    end

    describe '.only_deleted' do
      it 'returns only soft-deleted events' do
        expect(Event.only_deleted).not_to include(active_event)
        expect(Event.only_deleted).to include(deleted_event)
      end
    end
  end

  describe '#archive' do
    let(:event) { create(:event) }

    it 'sets deleted_at timestamp' do
      expect { event.archive }.to change { event.reload.deleted_at }.from(nil)
    end
  end

  describe '#restore' do
    let(:event) { create(:event) }

    before { event.update_column(:deleted_at, Time.current) }

    it 'clears deleted_at timestamp' do
      expect { event.restore }.to change { Event.with_deleted.find(event.id).deleted_at }.to(nil)
    end
  end

  describe '#waived_fees?' do
    it 'returns true when payment_status is waived' do
      event = create(:event, payment_status: :waived)
      expect(event.waived_fees?).to be true
    end

    it 'returns false when payment_status is not waived' do
      event = create(:event, payment_status: :unpaid)
      expect(event.waived_fees?).to be false
    end
  end

  describe '#paid_or_waived?' do
    it 'returns true when paid' do
      event = create(:event, payment_status: :paid)
      expect(event.paid_or_waived?).to be true
    end

    it 'returns true when waived' do
      event = create(:event, payment_status: :waived)
      expect(event.paid_or_waived?).to be true
    end
  end

  describe '#staff_role_grants_update?' do
    let(:event) { create(:event) }
    let(:admin_user) { create(:user) }
    let(:team_member_user) { create(:user) }
    let(:non_staff_user) { create(:user) }

    before do
      create(:event_assignment, event: event, user: admin_user, role: :event_admin)
      create(:event_assignment, event: event, user: team_member_user, role: :event_team_member)
    end

    it 'returns true for event_admin' do
      expect(event.staff_role_grants_update?(admin_user)).to be true
    end

    it 'returns false for event_team_member' do
      expect(event.staff_role_grants_update?(team_member_user)).to be false
    end

    it 'returns false for non-staff user' do
      expect(event.staff_role_grants_update?(non_staff_user)).to be false
    end
  end

  describe '#sync_custom_labels_to_attendees' do
    let(:event) { create(:event, labels_data: { 'position' => 'Position', 'company' => 'Company' }) }
    let(:ticket_type) { create(:ticket_type, event: event) }

    context 'when renaming a single label' do
      let!(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'position' => 'Manager', 'company' => 'Acme' }) }
      let!(:visitor) { create(:visitor, event: event, custom_fields_data: { 'position' => 'Speaker', 'company' => 'TechCorp' }) }

      it 'updates ticket custom_fields_data keys when label is renamed' do
        event.update!(labels_data: { 'occupation' => 'Occupation', 'company' => 'Company' })

        ticket.reload
        expect(ticket.custom_fields_data).to eq({ 'occupation' => 'Manager', 'company' => 'Acme' })
      end

      it 'updates visitor custom_fields_data keys when label is renamed' do
        event.update!(labels_data: { 'occupation' => 'Occupation', 'company' => 'Company' })

        visitor.reload
        expect(visitor.custom_fields_data).to eq({ 'occupation' => 'Speaker', 'company' => 'TechCorp' })
      end
    end

    context 'when renaming multiple labels' do
      let!(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'position' => 'Manager', 'company' => 'Acme' }) }

      it 'updates all renamed keys' do
        event.update!(labels_data: { 'occupation' => 'Occupation', 'organization' => 'Organization' })

        ticket.reload
        expect(ticket.custom_fields_data).to eq({ 'occupation' => 'Manager', 'organization' => 'Acme' })
      end
    end

    context 'when labels are not renamed' do
      let!(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'position' => 'Manager', 'company' => 'Acme' }) }

      it 'does not change ticket custom_fields_data' do
        event.update!(labels_data: { 'position' => 'Position Title', 'company' => 'Company Name' })

        ticket.reload
        expect(ticket.custom_fields_data).to eq({ 'position' => 'Manager', 'company' => 'Acme' })
      end
    end

    context 'when ticket has no custom_fields_data' do
      let!(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: nil) }

      it 'does not raise an error' do
        expect {
          event.update!(labels_data: { 'occupation' => 'Occupation', 'company' => 'Company' })
        }.not_to raise_error
      end
    end

    context 'when adding a new label' do
      let!(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'position' => 'Manager', 'company' => 'Acme' }) }

      it 'does not affect existing keys' do
        event.update!(labels_data: { 'position' => 'Position', 'company' => 'Company', 'department' => 'Department' })

        ticket.reload
        expect(ticket.custom_fields_data).to eq({ 'position' => 'Manager', 'company' => 'Acme' })
      end
    end

    context 'when removing a label' do
      let!(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'position' => 'Manager', 'company' => 'Acme' }) }

      it 'does not remove the key from ticket (data preserved)' do
        event.update!(labels_data: { 'position' => 'Position' })

        ticket.reload
        # The 'company' key remains in ticket data even though label was removed
        expect(ticket.custom_fields_data).to eq({ 'position' => 'Manager', 'company' => 'Acme' })
      end
    end
  end
end
