require "rails_helper"

RSpec.describe PeopleCounterConnection, type: :model do
  let(:event) { create(:event) }

  it "is valid with a URL and a key" do
    expect(described_class.new(event: event, base_url: "https://counter.test", api_key: "cz_key")).to be_valid
  end

  it "needs both a URL and a key" do
    expect(described_class.new(event: event, base_url: "", api_key: "cz_key")).not_to be_valid
    expect(described_class.new(event: event, base_url: "https://counter.test", api_key: "")).not_to be_valid
  end

  it "rejects something that is not a URL" do
    expect(described_class.new(event: event, base_url: "counter dot test", api_key: "cz_key")).not_to be_valid
  end

  it "trims whitespace and a trailing slash from the URL" do
    connection = described_class.create!(event: event, base_url: "  https://counter.test/  ", api_key: "cz_key")
    expect(connection.base_url).to eq("https://counter.test")
  end

  it "allows one connection per event" do
    described_class.create!(event: event, base_url: "https://counter.test", api_key: "cz_key")
    expect(described_class.new(event: event, base_url: "https://other.test", api_key: "cz_key2")).not_to be_valid
  end

  it "exposes only a short prefix of the key" do
    connection = described_class.new(api_key: "cz_abcdefghijklmnop")
    expect(connection.key_prefix).to eq("cz_abcde")
  end

  it "stores the key encrypted" do
    connection = described_class.create!(event: event, base_url: "https://counter.test", api_key: "cz_plainsecret")
    raw = described_class.connection.select_value("SELECT api_key FROM people_counter_connections WHERE id = #{connection.id}")
    expect(raw).not_to include("plainsecret")
    expect(connection.reload.api_key).to eq("cz_plainsecret")
  end

  it "clears the event's cached headcount when it changes, so old numbers never linger" do
    store = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(store)
    key = PeopleCounter::EventHeadcount.cache_key(event.id)
    store.write(key, { stale: true })

    described_class.create!(event: event, base_url: "https://counter.test", api_key: "cz_key")

    expect(store.read(key)).to be_nil
  end

  it "is removed with its event" do
    described_class.create!(event: event, base_url: "https://counter.test", api_key: "cz_key")
    expect { event.destroy }.to change(described_class, :count).by(-1)
  end
end
