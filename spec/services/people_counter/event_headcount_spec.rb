require "rails_helper"

RSpec.describe PeopleCounter::EventHeadcount do
  let(:event) { create(:event, start_date: Time.zone.local(2026, 9, 11, 9), end_date: Time.zone.local(2026, 9, 12, 18)) }
  let(:client) { instance_double(PeopleCounter::Client) }
  let!(:hall_a) { create(:event_hall, event: event, name: "Hall A", floor: "Level 1", counter_venue_id: 1) }
  let!(:hall_b) { create(:event_hall, event: event, name: "Hall B", floor: "Level 1", counter_venue_id: 2) }
  let!(:hall_c) { create(:event_hall, event: event, name: "Hall C", floor: "Level 2", counter_venue_id: 3) }
  let!(:hall_d) { create(:event_hall, event: event, name: "Hall D", floor: "Level 2") }

  def venue(id, capacity, occ, i, o)
    { "id" => id, "name" => "V#{id}", "capacity" => capacity, "today" => { "in" => i, "out" => o, "occupancy" => occ } }
  end

  before do
    allow(client).to receive(:venues).and_return([venue(1, 100, 40, 60, 20), venue(2, 50, 10, 15, 5), venue(3, 200, 0, 0, 0)])
    allow(client).to receive(:venue_totals) { |id, **| { "in" => id * 100, "out" => id * 10, "occupancy" => 0 } }
  end

  subject(:result) { described_class.new(event, client: client).call }

  it "rolls halls up to levels and the event" do
    level1 = result[:levels].find { |l| l[:floor] == "Level 1" }
    expect(level1).to include(inside_now: 50, capacity: 150, in_today: 75, out_today: 25, in_event: 300, out_event: 30, halls: 2)
    expect(result[:event]).to include(inside_now: 50, in_event: 600, out_event: 60, halls: 4, halls_counted: 3)
  end

  it "passes the event's start and end dates as the window" do
    result
    expect(client).to have_received(:venue_totals).with(1, from: event.start_date, to: event.end_date)
  end

  it "keeps exact level text separate and counts only working halls in totals" do
    hall_b.update!(floor: "level 1")
    hall_c.update!(floor: "Level 1 ")
    hall_d.update!(floor: "Level 1")

    levels = result[:levels].index_by { |level| level[:floor] }
    expect(levels.keys).to contain_exactly("Level 1", "level 1", "Level 1 ")
    expect(levels["Level 1"]).to include(inside_now: 40, capacity: 100, in_today: 60, out_today: 20,
                                         in_event: 100, out_event: 10, halls: 2, halls_counted: 1)
    expect(levels["level 1"]).to include(inside_now: 10, capacity: 50, halls: 1, halls_counted: 1)
    expect(levels["Level 1 "]).to include(inside_now: 0, capacity: 200, halls: 1, halls_counted: 1)
  end

  it "marks a hall without a counter as unlinked with empty figures" do
    row = result[:halls].find { |h| h[:name] == "Hall D" }
    expect(row).to include(status: "unlinked", inside_now: nil, in_event: nil)
  end

  it "flags a venue that no longer exists on the counter service" do
    allow(client).to receive(:venues).and_return([venue(1, 100, 40, 60, 20)])
    expect(result[:halls].map { |h| h[:status] }).to eq(%w[ok not_found not_found unlinked])
  end

  it "degrades every linked hall when the counter service is down" do
    allow(client).to receive(:venues).and_raise(PeopleCounter::Client::Error)
    expect(result[:halls].map { |h| h[:status] }).to eq(%w[unavailable unavailable unavailable unlinked])
    expect(result[:event]).to include(inside_now: nil, halls_counted: 0)
  end

  it "keeps live figures when only the event window fails" do
    allow(client).to receive(:venue_totals).and_raise(PeopleCounter::Client::Error)
    row = result[:halls].first
    expect(row).to include(status: "ok", inside_now: 40, in_event: nil)
  end

  it "skips the window for an event without dates" do
    event.update_columns(start_date: nil, end_date: nil)
    expect(result[:halls].first).to include(inside_now: 40, in_event: nil)
    expect(client).not_to have_received(:venue_totals)
  end

  it "marks linked halls unavailable (no crash) when the service is not configured" do
    allow(PeopleCounter::Client).to receive(:default).and_raise(PeopleCounter::Client::Error)
    result = described_class.new(event).call
    expect(result[:halls].map { |h| h[:status] }).to eq(%w[unavailable unavailable unavailable unlinked])
  end

  it "reports whether any connection is configured" do
    expect(described_class.new(event, client: client).call[:configured]).to be(true)

    allow(PeopleCounter::Client).to receive(:configured_for?).with(event).and_return(false)
    allow(PeopleCounter::Client).to receive(:for_event).and_raise(PeopleCounter::Client::Error)
    expect(described_class.new(event).call[:configured]).to be(false)
  end

  it "reads through the event's own connection" do
    allow(PeopleCounter::Client).to receive(:for_event).with(event).and_return(client)

    result = described_class.new(event).call

    expect(PeopleCounter::Client).to have_received(:for_event).with(event)
    expect(result[:halls].first).to include(status: "ok", inside_now: 40)
  end

  it "does not call the counter service when no hall is linked" do
    EventHall.update_all(counter_venue_id: nil)
    expect(result[:halls].map { |h| h[:status] }.uniq).to eq(["unlinked"])
    expect(client).not_to have_received(:venues)
  end
end
