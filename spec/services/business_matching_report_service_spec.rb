# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BusinessMatchingReportService do
  let(:booking) do
    {
      name: "Alice Visitor",
      email: "alice@example.com",
      phone: "601234567890123",
      booking_date: "10 August 2026",
      booking_time: "10:00 AM",
      status: "Approved",
      attendance: "Present",
      host_comment: "Staff-only note",
      booker_description: "We build fintech infrastructure",
      booker_sourcing_intent: "Looking for banking partners",
      booker_capabilities: "Core ledger APIs",
      potential_deal_value: 5000.0,
      event_title: "Speed Matchmaking",
      location: "Table 1",
      host_name: "John Host"
    }
  end

  describe '#generate_xlsx' do
    it 'exports a master "All Bookings" sheet with full session context and booker profiles' do
      xlsx_data = described_class.new([booking]).generate_xlsx
      doc = Roo::Excelx.new(StringIO.new(xlsx_data), file_warning: :ignore)

      expect(doc.sheets).to include("All Bookings", "Summary")

      sheet = doc.sheet("All Bookings")
      headers = sheet.row(1)

      expect(headers).to eq(
        [
          "Table",
          "Seller / Session",
          "Host",
          "Buyer Name",
          "Buyer Email",
          "Buyer Phone",
          "Date",
          "Time",
          "Status",
          "Attendance",
          "Potential Deal Value",
          "Host Comment",
          "Description",
          "Sourcing Intent",
          "Capabilities"
        ]
      )

      row = sheet.row(2)
      expect(row[headers.index("Table")]).to eq("Table 1")
      expect(row[headers.index("Seller / Session")]).to eq("Speed Matchmaking")
      expect(row[headers.index("Host")]).to eq("John Host")
      expect(row[headers.index("Buyer Name")]).to eq("Alice Visitor")
      expect(row[headers.index("Buyer Email")]).to eq("alice@example.com")
      expect(row[headers.index("Buyer Phone")]).to eq("601234567890123")
      expect(sheet.celltype(2, headers.index("Buyer Phone") + 1)).to eq(:string)
      expect(row[headers.index("Status")]).to eq("Approved")
      expect(row[headers.index("Potential Deal Value")]).to eq(5000.0)
      expect(row[headers.index("Host Comment")]).to eq("Staff-only note")
      expect(row[headers.index("Description")]).to eq("We build fintech infrastructure")
      expect(row[headers.index("Sourcing Intent")]).to eq("Looking for banking partners")
      expect(row[headers.index("Capabilities")]).to eq("Core ledger APIs")
    end

    it 'creates dedicated session sheets when there are multiple sessions' do
      second_booking = booking.merge(
        event_title: "Fintech Pitch",
        location: "Table 2",
        name: "Bob Buyer"
      )

      xlsx_data = described_class.new([booking, second_booking]).generate_xlsx
      doc = Roo::Excelx.new(StringIO.new(xlsx_data), file_warning: :ignore)

      expect(doc.sheets).to eq(["All Bookings", "Buyer Matrix", "Summary", "Speed Matchmaking", "Fintech Pitch"])

      all_bookings_sheet = doc.sheet("All Bookings")
      expect(all_bookings_sheet.last_row).to eq(3) # header + 2 bookings

      summary_sheet = doc.sheet("Summary")
      expect(summary_sheet.row(1).first).to include("Executive Summary")
    end

    it 'generates a buyer schedule matrix sheet showing sellers and dashes for empty slots' do
      b1 = booking.merge(name: "Alice", email: "alice@test.com", booking_time: "09:00 AM", location: "Table 1", event_title: "Seller 1")
      b2 = booking.merge(name: "Alice", email: "alice@test.com", booking_time: "09:30 AM", location: "Table 2", event_title: "Seller 2")
      b3 = booking.merge(name: "Bob", email: "bob@test.com", booking_time: "09:00 AM", location: "Table 2", event_title: "Seller 2")

      xlsx_data = described_class.new([b1, b2, b3]).generate_xlsx
      doc = Roo::Excelx.new(StringIO.new(xlsx_data), file_warning: :ignore)

      expect(doc.sheets).to include("Buyer Matrix")
      matrix_sheet = doc.sheet("Buyer Matrix")

      headers = matrix_sheet.row(1)
      expect(headers[0..2]).to eq(["Buyer Name", "Buyer Email", "Buyer Phone"])
      expect(headers).to include("9:00 AM – 9:30 AM", "9:30 AM – 10:00 AM")

      slot1_idx = headers.index("9:00 AM – 9:30 AM") + 1
      slot2_idx = headers.index("9:30 AM – 10:00 AM") + 1

      # Row 2 is Alice: booked at 9am (Seller 1), booked at 9:30am (Seller 2)
      expect(matrix_sheet.cell(2, 1)).to eq("Alice")
      expect(matrix_sheet.cell(2, slot1_idx)).to eq("[Table 1] Seller 1")
      expect(matrix_sheet.cell(2, slot2_idx)).to eq("[Table 2] Seller 2")

      # Row 3 is Bob: booked at 9am (Seller 2), empty at 9:30am ("-")
      expect(matrix_sheet.cell(3, 1)).to eq("Bob")
      expect(matrix_sheet.cell(3, slot1_idx)).to eq("[Table 2] Seller 2")
      expect(matrix_sheet.cell(3, slot2_idx)).to eq("-")
    end

    it 'sorts bookings in chronological time sequence grouping by date, time of day, and table' do
      b1 = booking.merge(name: "Late Guy", booking_time: "02:00 PM", location: "Table 1")
      b2 = booking.merge(name: "Morning Table 2", booking_time: "09:00 AM", location: "Table 2")
      b3 = booking.merge(name: "Morning Table 1", booking_time: "09:00 AM", location: "Table 1")
      b4 = booking.merge(name: "Midday Guy", booking_time: "10:30 AM", location: "Table 1")

      xlsx_data = described_class.new([b1, b2, b3, b4]).generate_xlsx
      doc = Roo::Excelx.new(StringIO.new(xlsx_data), file_warning: :ignore)
      sheet = doc.sheet("All Bookings")
      headers = sheet.row(1)
      name_idx = headers.index("Buyer Name") + 1

      expect(sheet.cell(2, name_idx)).to eq("Morning Table 1")
      expect(sheet.cell(3, name_idx)).to eq("Morning Table 2")
      expect(sheet.cell(4, name_idx)).to eq("Midday Guy")
      expect(sheet.cell(5, name_idx)).to eq("Late Guy")
    end

    it 'handles empty bookings gracefully' do
      xlsx_data = described_class.new([]).generate_xlsx
      doc = Roo::Excelx.new(StringIO.new(xlsx_data), file_warning: :ignore)

      expect(doc.sheets).to include("All Bookings", "Summary")
      sheet = doc.sheet("All Bookings")
      expect(sheet.row(1)).to include("Table", "Seller / Session", "Buyer Name")
    end
  end
end
