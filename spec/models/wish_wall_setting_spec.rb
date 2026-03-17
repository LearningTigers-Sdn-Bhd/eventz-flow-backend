require 'rails_helper'

RSpec.describe WishWallSetting, type: :model do
  describe 'validations' do
    it 'accepts nil color fields and a valid background image' do
      setting = build(
        :wish_wall_setting,
        accent_color: nil,
        header_text_color: nil,
        card_background_color: nil
      )

      setting.background_image.attach(
        io: StringIO.new('fake image'),
        filename: 'wall.webp',
        content_type: 'image/webp'
      )

      expect(setting).to be_valid
    end

    it 'enforces one wishes wall setting per event' do
      event = create(:event)
      create(:wish_wall_setting, event: event)

      duplicate = build(:wish_wall_setting, event: event)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:event_id]).to include('has already been taken')
    end

    it 'rejects unsupported background image content types' do
      setting = build(:wish_wall_setting)

      setting.background_image.attach(
        io: StringIO.new('bad file'),
        filename: 'wall.pdf',
        content_type: 'application/pdf'
      )

      expect(setting).not_to be_valid
      expect(setting.errors[:background_image]).to include('must be a JPEG, PNG, GIF, or WebP')
    end

    it 'rejects background images larger than 10MB' do
      setting = build(:wish_wall_setting)

      setting.background_image.attach(
        io: StringIO.new('large image'),
        filename: 'wall.png',
        content_type: 'image/png'
      )

      allow(setting.background_image.blob).to receive(:byte_size).and_return(10.megabytes + 1)

      expect(setting).not_to be_valid
      expect(setting.errors[:background_image]).to include('is too large (max 10MB)')
    end
  end
end
