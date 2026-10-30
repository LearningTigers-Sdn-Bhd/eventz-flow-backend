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

  it "has only Summary, Event Traffic and Hall Detail for one day" do
    expect(workbook.sheets).to eq(["Summary", "Event Traffic", "Hall Detail"])
  end

  it "adds the day-by-day sheets, and lists every event day up to today, for all days" do
    book = workbook(all_days: true)
    expect(book.sheets).to eq(["Summary", "By Day", "Day Comparison", "Halls by Day", "Event Traffic", "Hall Detail"])
    expect(cells(book.sheet("By Day")).drop(4).map(&:first)).to eq(["Fri, 11 Sep 2026", "Sat, 12 Sep 2026"])
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
    expect(rows.first[1, 4]).to eq([34, 5, 29, 29]) # 09:00 hour, both halls
    expect(rows.last[1, 4]).to eq([0, 25, -25, 4])
    expect(rows.map(&:last)).to eq(["09:00", "10:00"]) # plain-text chart labels, not dates
  end

  describe "visitors so far" do
    def book(date, **opts)
      file = Tempfile.new(["people", ".xlsx"], binmode: true)
      file.write(described_class.new(event, date: date, client: client, **opts).call)
      file.flush
      Roo::Excelx.new(file.path)
    end

    it "starts the traffic slots from zero on the first day" do
      rows = cells(book("2026-09-11").sheet("Event Traffic")).drop(4)
      expect(rows.map { |r| r[5] }).to eq([34, 34]) # arrivals so far after each hour
    end

    it "carries the earlier days into the slots, tiles and halls from the second day" do
      book = book("2026-09-12")
      rows = cells(book.sheet("Event Traffic")).drop(4)
      expect(rows.map { |r| r[5] }).to eq([68, 68]) # 34 before + 34 that day
      expect(cells(book.sheet("Summary")).flatten.compact.join(" | ")).to include("VISITORS SO FAR", "68")
      a = cells(book.sheet("Hall Detail")).drop(4).select { |r| r[1] == "Hall A" }
      expect(a.map(&:last)).to eq([60, 60]) # 30 before + the 30 Hall A counted that day
    end

    it "lays the days side by side on a comparison sheet" do
      sheet = cells(book("2026-09-11", all_days: true).sheet("Day Comparison")).drop(3)
      expect(sheet.first).to eq(["Time of day", "Fri, 11 Sep 2026 · came in", "Sat, 12 Sep 2026 · came in",
                                 "Fri, 11 Sep 2026 · inside", "Sat, 12 Sep 2026 · inside"])
      expect(sheet[1]).to eq(["09:00", 34, 34, 29, 29]) # hour 09 for both days (the stub repeats the day)
    end

    it "leaves the comparison sheet out for a single day" do
      expect(book("2026-09-11").sheets).not_to include("Day Comparison")
    end

    it "adds a running total per day for all days" do
      book = book("2026-09-11", all_days: true)
      expect(cells(book.sheet("By Day")).drop(4).map(&:last)).to eq([34, 68])
      expect(cells(book.sheet("Event Traffic")).drop(4).map { |r| r[5] }).to eq([34, 34, 68, 68])
    end
  end

  it "lists every hall's slots on Hall Detail and keeps typed names as text" do
    names = cells(workbook.sheet("Hall Detail")).map { |r| r[1] }
    expect(names).to include("Hall A", "=SUM(A1)")
  end

  it "keeps a single day to that day: no whole-event totals or per-day tables" do
    text = cells(workbook.sheet("Summary")).flatten.compact.join(" | ")
    expect(text).to include("VISITORS", "PEAK CROWD", "EVENT DAY", "By level", "By hall")
    expect(text).not_to include("WHOLE EVENT", "BEST DAY", "Visitors per day", "Hall totals")
  end

  it "gives the whole event for all days: totals, best day, visitors per day and hall totals with share" do
    text = cells(workbook(all_days: true).sheet("Summary")).flatten.compact.join(" | ")
    expect(text).to include("VISITORS · ALL DAYS", "BEST DAY", "AVERAGE PER DAY", "Visitors per day", "Hall totals", "Share")
    expect(text).to include("All days, 11 Sep to 12 Sep 2026")
    expect(text).not_to include("By level")
  end

  it "names the all-days file for the event, not a day" do
    expect(described_class.new(event, date: "2026-09-11", all_days: true, client: client).filename)
      .to eq("people-counts-#{event.id}-all-days.xlsx")
  end

  it "writes times in 12-hour form only when asked" do
    summary = ->(**opts) { cells(workbook(**opts).sheet("Summary")).flatten.compact.join(" | ") }
    expect(summary.call).to match(/at 09:\d\d/)
    expect(summary.call(hour12: true)).to match(/at 9:\d\d AM/)
    expect(summary.call(hour12: true)).not_to match(/at 09:\d\d/)
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
