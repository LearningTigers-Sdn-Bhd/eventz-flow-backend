require 'rails_helper'

RSpec.describe EventSeatSessionPolicy do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:event_admin) { create(:user) }
  let(:member) { create(:user, :member) }
  
  let(:event) { create(:event, use_seat_ticketing: true) }
  let(:disabled_event) { create(:event, use_seat_ticketing: false) }
  
  let(:session) { create(:event_seat_session, event: event) }
  let(:disabled_session) { create(:event_seat_session, event: disabled_event) }
  
  subject { described_class }

  context 'for event with seat ticketing enabled' do
    context 'as org owner' do
      permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.to permit(org_owner, session) }
      end
    end

    context 'as organizer' do
      permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.to permit(organizer, session) }
      end
    end

    context 'as event admin' do
      before do
        create(:event_assignment, event: event, user: event_admin, role: :event_admin)
      end
      permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.to permit(event_admin, session) }
      end
    end

    context 'as regular member' do
      permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.not_to permit(member, session) }
      end
    end
    
    context 'as event admin of another event' do
       let(:other_admin) { create(:user) }
       let(:other_event) { create(:event) }
       before do
          create(:event_assignment, event: other_event, user: other_admin, role: :event_admin)
       end
       permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.not_to permit(other_admin, session) }
      end
    end
  end

  context 'for event with seat ticketing disabled' do
    context 'as org owner' do
      permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.not_to permit(org_owner, disabled_session) }
      end
    end
    
    context 'as organizer' do
      permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.not_to permit(organizer, disabled_session) }
      end
    end

    context 'as event admin' do
      before do
        create(:event_assignment, event: disabled_event, user: event_admin, role: :event_admin)
      end
      permissions :show?, :create?, :update?, :destroy?, :archive?, :restore?, :force_delete? do
        it { is_expected.not_to permit(event_admin, disabled_session) }
      end
    end
  end
  
  describe 'Scope' do
    let(:scope) { Pundit.policy_scope!(user, EventSeatSession) }
    
    before do
      session # create active session
      disabled_session # create disabled session
    end
    
    context 'as org owner' do
      let(:user) { org_owner }
      it 'includes only sessions from enabled events' do
        expect(scope).to include(session)
        expect(scope).not_to include(disabled_session)
      end
    end
    
    context 'as organizer' do
      let(:user) { organizer }
      it 'includes only sessions from enabled events' do
         expect(scope).to include(session)
         expect(scope).not_to include(disabled_session)
      end
    end
    
    context 'as event admin' do
      let(:user) { event_admin }
      before do
         create(:event_assignment, event: event, user: event_admin, role: :event_admin)
      end
      it 'includes assigned sessions from enabled events' do
        expect(scope).to include(session)
        expect(scope).not_to include(disabled_session)
      end
    end

    context 'as member' do
       let(:user) { member }
       it 'is empty' do
         expect(scope).to be_empty
       end
    end
  end
end
