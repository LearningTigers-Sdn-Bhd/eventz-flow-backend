require 'rails_helper'

RSpec.describe QrCodeService do
  describe '.generate_png' do
    it 'generates a PNG binary string' do
      result = QrCodeService.generate_png("test-data")

      expect(result).to be_a(String)
      expect(result).to start_with("\x89PNG".force_encoding('ASCII-8BIT'))
    end

    it 'accepts a custom size' do
      result = QrCodeService.generate_png("test-data", size: 200)

      expect(result).to be_present
    end
  end

  describe '.generate_svg' do
    it 'generates an SVG string' do
      result = QrCodeService.generate_svg("test-data")

      expect(result).to be_a(String)
      expect(result).to include("<svg")
      expect(result).to include("</svg>")
    end
  end
end
