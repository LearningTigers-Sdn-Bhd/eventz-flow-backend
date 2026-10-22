require 'rails_helper'

RSpec.describe SystemNoticePolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }

  permissions :show?, :update? do
    it { is_expected.to permit(owner, SystemNotice) }
    it { is_expected.not_to permit(organizer, SystemNotice) }
    it { is_expected.not_to permit(member, SystemNotice) }
  end
end
