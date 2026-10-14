require "rails_helper"

RSpec.describe PeopleCounter::ReportWorkbook do
  let(:event) do
    create(:event, title: "Big Expo", start_date: Time.zone.local(2026, 9, 11, 9), end_date: Time.zone.local(2026, 9, 12, 18))
  end
  let(:client) { instance_double(PeopleCounter::Client) }
  let!(:hall_a) { create(:event_hall, event: event, name: "Hall A", floor: "Level 1", counter_venue_id: 1) }
  let!(:hall_b) { create(:event_hall, event: event, name: "=SUM(A1)", floor: "Level 2", counter_venue_id: 2) }
  let!(:hall_c) { create(:event_hall, event: event, name: "Hall C", floor: "Level 2") }

  def venue(id, capacity, occ)
    { "id" => id, "name" => "V#{id}", "capacity" => capacity, "today" => { "in" => occ, "out" => 0, "occupancy" => occ } }
  end

  def row(time, i, o)
    { "bucket" => "2026-09-11T#{time}", "in" => i, "out" => o }
  end

  before do
    allow(client).to receive(:venues).and_return([venue(1, 27, 25), venue(2, 100, 4)])
    allow(client).to receive(:venue_totals).and_return({ "in" => 90, "out" => 40, "occupancy" => 0 })
    allow(client).to receive(:venue_series).with(1, any_args).and_return(
      [row("09:00:00", 10, 0), row("09:15:00", 20, 5), row("10:00:00", 0, 25)]
    )
    allow(client).to receive(:venue_series).with(2, any_args).and_return([row("09:15:00", 4, 0)])
  end

  def workbook(**opts)
    file = Tempfile.new(["people", ".xlsx"], binmode: true)
    file.write(described_class.new(event, date: "2026-09-11", client: client, **opts).call)
    file.flush
    Roo::Excelx.new(file.path)
  end

  def cells(sheet)
    sheet.each_row_streaming.map { |r| r.map { |c| c&.value } }
  end

  it "has a Summary, the day-by-day sheets, then Event Traffic and Hall Detail" do
    expect(workbook.sheets).to eq(["Summary", "By Day", "Halls by Day", "Event Traffic", "Hall Detail"])
  end

  it "lists every event day up to today on By Day" do
    days = cells(workbook.sheet("By Day")).drop(4).map(&:first)
    expect(days).to eq(["Fri, 11 Sep 2026", "Sat, 12 Sep 2026"])
  end

  it "names the event and the day on the Summary" do
    text = cells(workbook.sheet("Summary")).flatten.compact.join(" | ")
    expect(text).to include("Big Expo", "Friday, 11 September 2026")
  end

  it "shows each hall against its capacity" do
    text = cells(workbook.sheet("Summary")).flatten.compact.join(" | ")
    expect(text).to include("Within capacity", "Nearly full", "No capacity set", "No counter linked")
  end

  it "lists the event's traffic slot by slot with net and inside" do
    rows = cells(workbook.sheet("Event Traffic")).drop(4) # banner, subtitle, spacer, header
    expect(rows.first.last(4)).to eq([34, 5, 29, 29]) # 09:00 hour, both halls
    expect(rows.last.last(4)).to eq([0, 25, -25, 4])
  end

  it "lists every hall's slots on Hall Detail and keeps typed names as text" do
    names = cells(workbook.sheet("Hall Detail")).map { |r| r[1] }
    expect(names).to include("Hall A", "=SUM(A1)")
  end

  it "is a readable workbook, not an error, when nothing was counted" do
    allow(client).to receive(:venue_series).and_return([])
    expect(workbook.sheets).to include("Summary")
  end

  it "names the file after the event and the day" do
    expect(described_class.new(event, date: "2026-09-11", client: client).filename)
      .to eq("people-counts-#{event.id}-2026-09-11.xlsx")
  end
end
