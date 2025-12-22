require 'rails_helper'

RSpec.describe PrintingService, type: :model do
  describe 'Validations' do
    subject { create(:printing_service) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:unit_of_measure) }
    it { is_expected.to validate_presence_of(:default_price) }
    it { is_expected.to validate_numericality_of(:default_price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:status) }

    it 'is valid with a defined status' do
      %i[active inactive].each do |status|
        printing_service = build(:printing_service, status: status)
        expect(printing_service).to be_valid
      end
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:item_category) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'Active Storage' do
    subject { create(:printing_service) }

    it { is_expected.to have_one_attached(:image) }

    it 'can attach an image' do
      subject.image.attach(
        io: StringIO.new('fake image data'),
        filename: 'test.jpg',
        content_type: 'image/jpeg'
      )
      expect(subject.image).to be_attached
    end

    it 'validates image content type' do
      subject.image.attach(
        io: StringIO.new('fake data'),
        filename: 'test.txt',
        content_type: 'text/plain'
      )
      expect(subject).not_to be_valid
      expect(subject.errors[:image]).to include('must be a JPEG, PNG, GIF, or WebP')
    end

    it 'validates image size' do
      subject.image.attach(
        io: StringIO.new('x' * 6.megabytes),
        filename: 'large.jpg',
        content_type: 'image/jpeg'
      )
      expect(subject).not_to be_valid
      expect(subject.errors[:image]).to include('is too large (max 5MB)')
    end
  end
end
