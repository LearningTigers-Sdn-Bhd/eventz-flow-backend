require "rails_helper"

RSpec.describe PeopleCounter::Client do
  subject(:client) { described_class.new(base_url: "https://counter.test/", token: "secret") }

  it "sends the bearer token and unwraps data" do
    stub = stub_request(:get, "https://counter.test/api/v1/venues/7/totals")
           .with(headers: { "Authorization" => "Bearer secret" })
           .to_return(body: { data: { in: 5, out: 2, occupancy: 3 } }.to_json)

    expect(client.venue_totals(7)).to eq("in" => 5, "out" => 2, "occupancy" => 3)
    expect(stub).to have_been_requested
  end

  it "raises Error on non-2xx" do
    stub_request(:get, "https://counter.test/api/v1/venues").to_return(status: 500)
    expect { client.venues }.to raise_error(described_class::Error, /500/)
  end

  it "raises Error on network failure" do
    stub_request(:get, "https://counter.test/api/v1/venues").to_timeout
    expect { client.venues }.to raise_error(described_class::Error, /unreachable/)
  end

  it "refuses to build without config" do
    expect { described_class.new(base_url: nil, token: nil) }.to raise_error(described_class::Error)
  end

  it "refuses a URL that is not http(s)" do
    expect { described_class.new(base_url: "ftp://counter.test", token: "k") }.to raise_error(described_class::Error, /http/)
    expect { described_class.new(base_url: "not a url", token: "k") }.to raise_error(described_class::Error)
  end

  it "raises Unauthorized (a kind of Error) when the service refuses the key" do
    [401, 403].each do |status|
      stub_request(:get, "https://counter.test/api/v1/venues").to_return(status: status)
      expect { client.venues }.to raise_error(described_class::Unauthorized)
    end
    expect(described_class::Unauthorized.ancestors).to include(described_class::Error)
  end

  describe "SSRF guard (user-entered URLs)" do
    subject(:guarded) { described_class.new(base_url: "https://internal.test", token: "k", guard: true) }

    it "never connects to a host that resolves to a private network" do
      allow(Resolv).to receive(:getaddresses).with("internal.test").and_return(["10.0.0.5"])

      expect { guarded.venues }.to raise_error(described_class::Error, /private or local/)
      expect(WebMock).not_to have_requested(:get, /internal\.test/)
    end

    it "connects when the host resolves to a public address" do
      allow(Resolv).to receive(:getaddresses).with("internal.test").and_return(["93.184.216.34"])
      stub_request(:get, "https://internal.test/api/v1/venues").to_return(body: { data: [] }.to_json)

      expect(guarded.venues).to eq([])
    end
  end

  describe ".for_event / .configured_for?" do
    let(:event) { create(:event) }

    it "is not configured without a connection or server-wide variables" do
      expect(described_class.configured_for?(event)).to be(false)
      expect { described_class.for_event(event) }.to raise_error(described_class::Error, /not configured/)
    end

    it "uses the event's own connection, guarded outside development" do
      PeopleCounterConnection.create!(event: event, base_url: "https://counter.test", api_key: "cz_key")
      allow(Resolv).to receive(:getaddresses).with("counter.test").and_return(["93.184.216.34"])
      stub_request(:get, "https://counter.test/api/v1/venues")
        .with(headers: { "Authorization" => "Bearer cz_key" }).to_return(body: { data: [1] }.to_json)

      expect(described_class.configured_for?(event)).to be(true)
      expect(described_class.for_event(event).venues).to eq([1])
    end
  end
end
