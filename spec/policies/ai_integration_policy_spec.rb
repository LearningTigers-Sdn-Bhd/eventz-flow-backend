require 'rails_helper'

RSpec.describe AiIntegrationPolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user, :org_owner) }
  let(:other_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:integration) { AiIntegration.new(user: owner, provider: 'OpenRouter') }

  permissions :index?, :create? do
    it { is_expected.to permit(owner, AiIntegration) }
    it { is_expected.not_to permit(organizer, AiIntegration) }
  end

  permissions :update?, :destroy? do
    it { is_expected.to permit(owner, integration) }
    it { is_expected.not_to permit(other_owner, integration) }
    it { is_expected.not_to permit(organizer, integration) }
  end

  permissions :available_models?, :import_models? do
    it { is_expected.to permit(owner, integration) }
    it { is_expected.not_to permit(other_owner, integration) }
    it { is_expected.not_to permit(organizer, integration) }
  end
end
