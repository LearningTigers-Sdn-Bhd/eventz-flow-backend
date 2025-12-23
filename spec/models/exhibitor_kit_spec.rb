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
        # Note: exhibitor_kit factory creates 2 members by default
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
        # Note: exhibitor_kit factory creates 2 members by default
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
      end
    end
  end
end