require 'rails_helper'

RSpec.describe ScanLogPolicy do
  subject { described_class }

  let(:event) { create(:event) }
  let(:owner) { create(:user, :org_owner) }
  let(:log) { create(:scan_log, event: event, scannable: create(:ticket, event: event)) }

  permissions :index?, :show? do
    it 'grants access to an org owner' do
      expect(subject).to permit(owner, log)
    end
  end

  describe 'Scope' do
    it 'excludes logs from events the user cannot see' do
      other_log = create(:scan_log,
                         event: create(:event),
                         scannable: create(:ticket))
      outsider = create(:user, :member)

      resolved = described_class::Scope.new(outsider, ScanLog).resolve

      expect(resolved).not_to include(other_log)
    end
  end
end
