require 'rails_helper'

RSpec.describe ExhibitorVoucherPolicy do
  subject { described_class }

  let(:event) { create(:event) }
  let(:voucher) { create(:exhibitor_voucher, event: event) }
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:organizer) { create(:user, role: :organizer) }
  let(:member) { create(:user, role: :member) }

  permissions :create?, :destroy? do
    it 'grants access to an org owner' do
      expect(subject).to permit(org_owner, voucher)
    end

    it 'grants access to an organizer' do
      expect(subject).to permit(organizer, voucher)
    end

    it 'denies an unrelated member' do
      expect(subject).not_to permit(member, voucher)
    end

    it 'grants access to event staff' do
      create(:event_assignment, user: member, event: event, role: :event_admin)

      expect(subject).to permit(member.reload, voucher)
    end
  end

  describe 'Scope' do
    it 'returns all vouchers for an organizer' do
      voucher

      expect(described_class::Scope.new(organizer, ExhibitorVoucher).resolve).to include(voucher)
    end

    it 'returns only assigned events for a member' do
      voucher
      other = create(:exhibitor_voucher)
      create(:event_assignment, user: member, event: event, role: :event_team_member)

      resolved = described_class::Scope.new(member.reload, ExhibitorVoucher).resolve

      expect(resolved).to include(voucher)
      expect(resolved).not_to include(other)
    end
  end
end
