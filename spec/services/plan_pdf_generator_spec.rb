require 'rails_helper'

RSpec.describe PlanPdfGenerator do
  let(:plan) { create(:plan, canvas_width: 1000, canvas_height: 800) }
  let!(:table) { create(:plan_object, :table, plan: plan, x: 100, y: 100, width: 50, height: 50) }
  
  subject { described_class.new(plan) }

  describe '#generate' do
    it 'generates a PDF string' do
      pdf_content = subject.generate
      expect(pdf_content).to start_with('%PDF-')
    end
  end
end
