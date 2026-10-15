require "rails_helper"

RSpec.describe PeopleCounter::EventAnalytics do
  let(:event) { create(:event, start_date: Time.zone.local(2026, 9, 11, 9), end_date: Time.zone.local(2026, 9, 12, 18)) }
  let(:client) { instance_double(PeopleCounter::Client) }
  let!(:hall_a) { create(:event_hall, event: event, name: "Hall A", floor: "Level 1", counter_venue_id: 1) }
  let!(:hall_b) { create(:event_hall, event: event, name: "Hall B", floor: "Level 1", counter_venue_id: 2) }
  let!(:hall_c) { create(:event_hall, event: event, name: "Hall C", floor: "Level 2") }

  def row(time, i, o)
    { "bucket" => "2026-09-11T#{time}", "in" => i, "out" => o }
  end

  before do
    allow(client).to receive(:venue_series).with(1, any_args).and_return(
      [row("09:00:00", 10, 0), row("09:15:00", 20, 5), row("10:00:00", 0, 25)]
    )
    allow(client).to receive(:venue_series).with(2, any_args).and_return([row("09:15:00", 4, 0), row("10:15:00", 6, 1)])
  end

  def result(**opts)
    described_class.new(event, date: "2026-09-11", client: client, **opts).call
  end

  it "lists the event's days and defaults an unknown date to one of them" do
    expect(result[:days]).to eq(%w[2026-09-11 2026-09-12])
    expect(described_class.new(event, date: "2030-01-01", client: client).date).to eq("2026-09-11")
    expect(described_class.new(event, date: "garbage", client: client).date).to eq("2026-09-11")
  end

  it "asks the counter for the chosen day in 15-minute buckets" do
    result
    expect(client).to have_received(:venue_series).with(1, from: Date.new(2026, 9, 11), to: Date.new(2026, 9, 11), bucket: 15)
  end

  it "keeps a running occupancy per hall that never goes below zero" do
    a = result(bucket: 15)[:halls].find { |h| h[:name] == "Hall A" }
    expect(a[:points].map { |p| p[:occupancy] }).to eq([10, 25, 0, 0])
  end

  it "adds halls into levels and the event" do
    data = result(bucket: 15)
    level1 = data[:levels].find { |l| l[:floor] == "Level 1" }
    first = level1[:points].find { |p| p[:bucket].end_with?("09:15:00") }
    expect(first).to include(in: 24, out: 5, occupancy: 29)
    expect(data[:event][:points].last[:occupancy]).to eq(9)
  end

  it "shows hourly points with In/Out summed and occupancy at the end of the hour" do
    a = result(bucket: 60)[:halls].find { |h| h[:name] == "Hall A" }
    expect(a[:points]).to eq([
      { bucket: "2026-09-11T09:00:00", in: 30, out: 5, occupancy: 25 },
      { bucket: "2026-09-11T10:00:00", in: 0, out: 25, occupancy: 0 }
    ])
  end

  it "reports peak, busiest arrival hour and the latest movement" do
    stats = result[:halls].find { |h| h[:name] == "Hall A" }[:stats]
    expect(stats[:peak]).to eq(occupancy: 25, at: "2026-09-11T09:15:00")
    expect(stats[:busiest_entry_hour]).to eq(at: "2026-09-11T09:00:00", in: 30)
    expect(stats[:recent_flow]).to eq(net: -25, in: 0, out: 25, at: "2026-09-11T10:00:00")
  end

  it "marks a hall without a counter as unlinked and leaves it out of the sums" do
    hall = result[:halls].find { |h| h[:name] == "Hall C" }
    expect(hall).to include(status: "unlinked", points: [], stats: nil)
  end

  it "degrades only the hall whose counter can't be read" do
    allow(client).to receive(:venue_series).with(2, any_args).and_raise(PeopleCounter::Client::Error)
    halls = result[:halls]
    expect(halls.map { |h| h[:status] }).to eq(%w[ok unavailable unlinked])
    expect(result[:event][:points]).not_to be_empty
  end

  it "is empty, not an error, when no counter connection exists" do
    unconfigured = described_class.new(event, date: "2026-09-11")
    allow(PeopleCounter::Client).to receive(:configured_for?).and_return(false)
    expect(unconfigured.call).to include(configured: false, halls: [], levels: [])
  end
end
