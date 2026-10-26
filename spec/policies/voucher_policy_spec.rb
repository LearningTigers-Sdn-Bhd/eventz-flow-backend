require 'rails_helper'

RSpec.describe VoucherPolicy do
  subject(:policy) { described_class.new(user, voucher) }

  let(:vendor) { create(:user, :vendor) }
  let(:voucher) { create(:voucher, vendor: vendor) }

  context 'as org owner' do
    let(:user) { create(:user, :org_owner) }

    it { is_expected.to permit_actions(%i[restore destroy force_delete]) }
  end

  context 'as organizer' do
    let(:user) { create(:user, :organizer) }

    it { is_expected.to permit_actions(%i[restore destroy]) }
    it { is_expected.to forbid_action(:force_delete) }
  end

  context 'as the owning vendor' do
    let(:user) { vendor }

    it { is_expected.to permit_actions(%i[restore destroy]) }
    it { is_expected.to forbid_action(:force_delete) }
  end

  context 'as another vendor' do
    let(:user) { create(:user, :vendor) }

    it { is_expected.to forbid_actions(%i[restore destroy force_delete]) }
  end
end
