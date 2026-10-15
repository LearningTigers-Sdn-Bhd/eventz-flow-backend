require 'rails_helper'

RSpec.describe BusinessMatchingParticipant, type: :model do
  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:participant) do
    described_class.create!(event: event, registerable: user)
  end

  describe 'Active Storage' do
    it { is_expected.to have_one_attached(:avatar) }

    it 'returns nil avatar_url when nothing is attached' do
      expect(participant.avatar_url).to be_nil
    end

    it 'returns a URL once an avatar is attached' do
      participant.avatar.attach(
        io: StringIO.new('fake image data'),
        filename: 'avatar.jpg',
        content_type: 'image/jpeg'
      )
      expect(participant.avatar).to be_attached
      expect(participant.avatar_url).to include('avatar.jpg')
    end
  end
end
