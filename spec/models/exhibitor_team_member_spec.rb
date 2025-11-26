require 'rails_helper'

RSpec.describe ExhibitorTeamMember, type: :model do
  let(:event) { create(:event, use_ticket: true) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }
  let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

  subject { build(:exhibitor_team_member, exhibitor_kit: exhibitor_kit) }

  it { should belong_to(:exhibitor_kit) }
  it { should validate_presence_of(:full_name) }
end
