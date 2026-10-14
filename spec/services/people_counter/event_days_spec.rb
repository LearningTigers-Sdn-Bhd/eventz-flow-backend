require "rails_helper"

RSpec.describe PeopleCounter::EventDays do
  let(:event) { create(:event, start_date: Time.zone.local(2026, 9, 11, 9), end_date: Time.zone.local(2026, 9, 13, 18)) }
  let(:client) { instance_double(PeopleCounter::Client) }
  let!(:hall_a) { create(:event_hall, event: event, name: "Hall A", floor: "Level 1", counter_venue_id: 1) }
  let!(:hall_b) { create(:event_hall, event: event, name: "Hall B", floor: nil) }

  def series_for(day, i, o)
    [{ "bucket" => "#{day}T09:00:00", "in" => i, "out" => 0 }, { "bucket" => "#{day}T10:00:00", "in" => 0, "out" => o }]
  end

  before do
    allow(client).to receive(:venue_series) do |_id, from:, **|
      case from.iso8601
      when "2026-09-11" then series_for("2026-09-11", 50, 20)
      when "2026-09-12" then series_for("2026-09-12", 80, 80)
      else []
      end
    end
  end

  def result(today: Date.new(2026, 9, 13))
    described_class.new(event, client: client, today: today).call
  end

  it "has one entry per event day up to today, each with totals and its peak" do
    days = result[:days]
    expect(days.map { |d| d[:date] }).to eq(%w[2026-09-11 2026-09-12 2026-09-13])
    expect(days.first).to include(entries: 50, exits: 20, closing: 30)
    expect(days.first[:peak]).to eq(occupancy: 50, at: "2026-09-11T09:00:00")
    expect(days.second).to include(entries: 80, exits: 80, closing: 0)
  end

  it "keeps a day with no counts, with empty peaks, instead of dropping it" do
    last = result[:days].last
    expect(last).to include(entries: 0, exits: 0, peak: nil, closing: nil)
  end

  it "breaks each day down by hall, leaving unlinked halls at zero" do
    halls = result[:days].first[:halls]
    expect(halls.map { |h| [h[:name], h[:status], h[:entries]] }).to eq([["Hall A", "ok", 50], ["Hall B", "unlinked", 0]])
  end

  it "leaves out days that haven't happened yet" do
    expect(result(today: Date.new(2026, 9, 11))[:days].map { |d| d[:date] }).to eq(["2026-09-11"])
    expect(result(today: Date.new(2026, 9, 1))[:days]).to eq([])
  end

  it "is empty and unconfigured without a counter connection" do
    allow(PeopleCounter::Client).to receive(:configured_for?).and_return(false)
    data = described_class.new(event, today: Date.new(2026, 9, 13)).call
    expect(data).to eq(configured: false, days: [])
  end
end
