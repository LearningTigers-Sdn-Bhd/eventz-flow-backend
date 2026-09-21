require 'rails_helper'

RSpec.describe AiModelPolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user, :org_owner) }
  let(:other_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:integration) { AiIntegration.new }
  let(:model) { AiModel.new(ai_integration: integration) }

  permissions :create?, :update?, :destroy?, :set_default? do
    it { is_expected.to permit(owner, model) }
    it { is_expected.to permit(other_owner, model) }
    it { is_expected.not_to permit(organizer, model) }
  end
end
