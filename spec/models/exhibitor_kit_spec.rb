require 'rails_helper'

RSpec.describe ExhibitorKit, type: :model do
  let(:event) { create(:event, use_ticket: true) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }

  subject { build(:exhibitor_kit, event_vendor: exhibitor) }

  it { should belong_to(:event_vendor) }
  it { should have_many(:exhibitor_team_members).dependent(:destroy) }
  it { should define_enum_for(:booth_type).with_values([:shell_scheme, :raw_space]) }




  it { should validate_length_of(:name_on_fascia).is_at_most(25) }


  it { should validate_presence_of(:pic_full_name) }
  it { should validate_presence_of(:pic_contact_number) }

  it { should allow_value('test@example.com').for(:pic_email_address) }
  it { should_not allow_value('invalid-email').for(:pic_email_address) }

  describe 'nested attributes for exhibitor_team_members' do
    it 'accepts nested attributes for exhibitor_team_members' do
      exhibitor_kit = create(:exhibitor_kit, event_vendor: exhibitor, exhibitor_team_members_attributes: [{ full_name: 'John Doe' }])
      expect(exhibitor_kit.exhibitor_team_members.first.full_name).to eq('John Doe')
    end

    it 'destroys exhibitor_team_members' do
      exhibitor_kit = create(:exhibitor_kit, event_vendor: exhibitor)
      member = create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit)
      expect {
        exhibitor_kit.update(exhibitor_team_members_attributes: [{ id: member.id, _destroy: '1' }])
      }.to change(ExhibitorTeamMember, :count).by(-1)
    end
  end
end