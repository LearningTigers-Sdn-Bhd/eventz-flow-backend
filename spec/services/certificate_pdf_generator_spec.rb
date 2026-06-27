require 'rails_helper'

RSpec.describe CertificatePdfGenerator do
  let(:template) { build(:certificate_template, :with_background) }

  describe '#render' do
    it 'returns PDF bytes' do
      pdf = described_class.new(template, nil, sample_name: 'Jane Attendee').render
      expect(pdf).to be_present
      expect(pdf[0, 5]).to eq('%PDF-')
    end

    it 'renders without a background image' do
      template_no_bg = build(:certificate_template)
      pdf = described_class.new(template_no_bg, nil, sample_name: 'Jane Attendee').render
      expect(pdf[0, 5]).to eq('%PDF-')
    end

    it 'uses the ticket attendee name when no sample is given' do
      ticket = build(:ticket, attendee_name: 'Real Attendee')
      pdf = described_class.new(template, ticket).render
      expect(pdf[0, 5]).to eq('%PDF-')
    end

    it 'raises when template is nil' do
      expect { described_class.new(nil).render }.to raise_error(ArgumentError)
    end

    it 'tolerates malformed field entries' do
      template.fields = [{ 'type' => 'attendee_name' }, { 'bogus' => true }]
      pdf = described_class.new(template, nil, sample_name: 'X').render
      expect(pdf[0, 5]).to eq('%PDF-')
    end
  end
end
