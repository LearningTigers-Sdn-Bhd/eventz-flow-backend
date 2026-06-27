require 'rails_helper'

RSpec.describe CertificateTemplate, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
    it { should have_one_attached(:background_image) }
  end

  describe 'enums' do
    it 'defines the status enum' do
      expect(described_class.statuses).to eq('draft' => 0, 'ready' => 1, 'archived' => 2)
    end

    it 'defaults to draft' do
      expect(described_class.new.status).to eq('draft')
    end
  end

  describe 'validations' do
    subject { build(:certificate_template) }

    it 'is valid with default attributes' do
      expect(subject).to be_valid
    end

    it 'rejects an invalid orientation' do
      subject.orientation = 'diagonal'
      expect(subject).not_to be_valid
      expect(subject.errors[:orientation]).to be_present
    end

    it 'requires positive canvas dimensions' do
      subject.canvas_width = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:canvas_width]).to be_present
    end

    it 'requires fields to be an array' do
      subject.fields = { not: 'an array' }
      expect(subject).not_to be_valid
      expect(subject.errors[:fields]).to be_present
    end

    context 'when marking as ready' do
      it 'is invalid without a background image' do
        template = build(:certificate_template, status: :ready)
        expect(template).not_to be_valid
        expect(template.errors[:status]).to include('requires a background image')
      end

      it 'is invalid without any fields' do
        template = build(:certificate_template, :with_background, status: :ready, fields: [])
        expect(template).not_to be_valid
        expect(template.errors[:status]).to include('requires at least one field')
      end

      it 'is valid with a background and at least one field' do
        template = build(:certificate_template, :ready)
        expect(template).to be_valid
      end
    end
  end

  describe '#background_image_url' do
    it 'returns nil when no image is attached' do
      expect(build(:certificate_template).background_image_url).to be_nil
    end

    it 'returns a path when an image is attached' do
      template = create(:certificate_template, :with_background)
      expect(template.background_image_url).to be_present
    end
  end

  describe '#as_json' do
    it 'merges background_image_url' do
      template = build(:certificate_template)
      expect(template.as_json).to have_key('background_image_url')
    end
  end
end
