require 'rails_helper'

RSpec.describe BusinessMatchingReportService do
  let(:booking) do
    {
      name: "Alice Visitor",
      email: "alice@example.com",
      phone: "+6012",
      booking_date: "10 August 2026",
      booking_time: "10:00 AM",
      status: "Approved",
      attendance: "Present",
      host_comment: "Staff-only note",
      booker_description: "We build fintech infrastructure",
      booker_sourcing_intent: "Looking for banking partners",
      booker_capabilities: "Core ledger APIs",
      potential_deal_value: 5000.0,
      event_title: "Speed Matchmaking"
    }
  end

  describe '#generate_xlsx' do
    it 'exports the booker profile fields as their own columns, separate from the host comment' do
      xlsx_data = described_class.new([booking]).generate_xlsx
      sheet = Roo::Excelx.new(StringIO.new(xlsx_data), file_warning: :ignore).sheet(0)

      headers = sheet.row(1)
      expect(headers).to eq(
        ["Name", "Email", "Phone", "Date & Time", "Status", "Attendance", "Comment",
         "Description", "Sourcing Intent", "Capabilities", "Potential Deal Value"]
      )

      row = sheet.row(2)
      expect(row[headers.index("Comment")]).to eq("Staff-only note")
      expect(row[headers.index("Description")]).to eq("We build fintech infrastructure")
      expect(row[headers.index("Sourcing Intent")]).to eq("Looking for banking partners")
      expect(row[headers.index("Capabilities")]).to eq("Core ledger APIs")
    end
  end
end
