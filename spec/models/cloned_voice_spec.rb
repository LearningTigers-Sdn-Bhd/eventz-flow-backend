require 'rails_helper'

RSpec.describe ClonedVoice, type: :model do
  describe 'associations' do
    it { should belong_to(:owner).class_name('User') }
    it { should belong_to(:event).optional }
    it { should belong_to(:creator).class_name('User') }
    it { should have_many_attached(:audio_samples) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:status) }
    
    describe 'uniqueness' do
      subject { create(:cloned_voice, :ready) }
      it { should validate_uniqueness_of(:elevenlabs_id).allow_nil }
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, ready: 1, failed: 2) }
  end

  describe 'default settings' do
    let(:cloned_voice) { build(:cloned_voice) }

    it 'sets default ElevenLabs settings on validation' do
      cloned_voice.validate
      expect(cloned_voice.settings).to include(
        'stability' => 0.4,
        'similarity_boost' => 0.75,
        'style' => 0.2,
        'use_speaker_boost' => true
      )
    end
  end
end
