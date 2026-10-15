require 'rails_helper'

RSpec.describe PlanPdfGenerator do
  let(:plan) { create(:plan, canvas_width: 1000, canvas_height: 800) }
  let!(:table) do
    create(:plan_object, :table, plan: plan, x: 100, y: 100, width: 50, height: 50,
                                  label: 'MICCI', table_number: '2')
  end

  subject { described_class.new(plan) }

  describe '#generate' do
    it 'generates a PDF string' do
      pdf_content = subject.generate
      expect(pdf_content).to start_with('%PDF-')
    end

    %w[map ops public].each do |type|
      it "generates the #{type} export without error when a table has a table_number" do
        pdf_content = subject.generate(type: type)
        expect(pdf_content).to start_with('%PDF-')
      end
    end
  end

  describe '#table_display_name' do
    def display_name(table)
      subject.send(:table_display_name, table)
    end

    it 'combines table number and label when both are present' do
      expect(display_name(table)).to eq('2 — MICCI')
    end

    it 'falls back to "Table <number>" when only table_number is present' do
      table.label = nil
      expect(display_name(table)).to eq('Table 2')
    end

    it 'falls back to the label when only label is present' do
      table.table_number = nil
      expect(display_name(table)).to eq('MICCI')
    end

    it 'falls back to "Table" when neither is present' do
      table.table_number = nil
      table.label = nil
      expect(display_name(table)).to eq('Table')
    end
  end
end
