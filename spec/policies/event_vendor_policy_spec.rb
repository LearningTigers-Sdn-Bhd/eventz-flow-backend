require 'rails_helper'
require 'pundit/rspec'

RSpec.describe EventVendorPolicy, type: :policy do
  let(:user) { nil }
  let(:event) { create(:event) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:event_vendor) { create(:merchant, event: event, vendor: vendor_user) }

  subject { described_class.new(user, event_vendor) }

  context 'being an Org Owner' do
    let(:user) { create(:user, :org_owner) }

    # it { should permit_action(:create) }
    # it { should permit_action(:update) }
    # it { should permit_action(:destroy) }
  end

  context 'being an Organizer' do
    let(:user) { create(:user, :organizer) }

    # it { should permit_action(:create) }
    # it { should permit_action(:update) }
    # it { should permit_action(:destroy) }
  end

  context 'being an Event Admin' do
    let(:event_admin_user) { create(:user, :member) }
    let!(:event_assignment) { create(:event_assignment, event: event, user: event_admin_user, role: :event_admin) }
    let(:user) { event_admin_user }

    # it { should permit_action(:create) }
    # it { should permit_action(:update) }
    # it { should permit_action(:destroy) }
  end

  context 'being the assigned Vendor/Exhibitor' do
    let(:user) { vendor_user }

    # it { should_not permit_action(:create) }
    # it { should permit_action(:update) } # Can update own profile/kit
    # it { should_not permit_action(:destroy) }
  end

  context 'being a different Vendor' do
    let(:user) { create(:user, :vendor) }

    # it { should_not permit_action(:create) }
    # it { should_not permit_action(:update) }
    # it { should_not permit_action(:destroy) }
  end

  context 'being a regular Member' do
    let(:user) { create(:user, :member) }

    # it { should_not permit_action(:create) }
    # it { should_not permit_action(:update) }
    # it { should_not permit_action(:destroy) }
  end

  context 'Scope' do
    let(:org_owner) { create(:user, :org_owner) }
    let(:organizer) { create(:user, :organizer) }
    let(:event_admin) { create(:user, :member) }
    let(:vendor_user_1) { create(:user, :vendor) }
    let(:vendor_user_2) { create(:user, :vendor) }
    let(:event_1) { create(:event, created_by: organizer) }
    let(:event_2) { create(:event, created_by: org_owner) }
    let!(:event_vendor_1) { create(:merchant, event: event_1, vendor: vendor_user_1) }
    let!(:event_vendor_2) { create(:exhibitor, event: event_2, vendor: vendor_user_2) }
    let!(:event_vendor_3) { create(:merchant) } # Different organization

    before do
      create(:event_assignment, event: event_1, user: event_admin, role: :event_admin)
    end

    describe 'Org Owner scope' do
      let(:user) { org_owner }
      # it 'returns all event vendors within the organization' do
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).to include(event_vendor_1, event_vendor_2)
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).not_to include(event_vendor_3)
      # end
    end

    describe 'Organizer scope' do
      let(:user) { organizer }
      # it 'returns event vendors for events created by the organizer' do
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).to include(event_vendor_1)
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).not_to include(event_vendor_2, event_vendor_3)
      # end
    end

    describe 'Vendor scope' do
      let(:user) { vendor_user_1 }
      # it 'returns only their own event vendor assignments' do
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).to include(event_vendor_1)
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).not_to include(event_vendor_2, event_vendor_3)
      # end
    end

    describe 'Event Admin scope (implicitly handled by event show policy on index)' do
      let(:user) { event_admin }
      # it 'allows viewing of event vendors for events they administer (handled by controller policy enforcement)' do
      #   # The scope itself for event_admin is still limited to what EventPolicy allows.
      #   # This test verifies the EventVendorPolicy::Scope isn't overly restrictive on its own.
      #   # Actual filtering for event_admin on index is done by EventPolicy on the event itself.
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).to include(event_vendor_1)
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).not_to include(event_vendor_2, event_vendor_3)
      # end
    end

    describe 'Member scope' do
      let(:user) { create(:user, :member) }
      # it 'returns no event vendors' do
      #   expect(EventVendorPolicy::Scope.new(user, EventVendor).resolve).to be_empty
      # end
    end
  end
end