require 'rails_helper'

RSpec.describe 'Rack::Attack throttles' do
  def discriminator(name, path)
    request = Rack::Attack::Request.new(Rack::MockRequest.env_for(path, 'REMOTE_ADDR' => '203.0.113.9'))
    Rack::Attack.throttles.fetch(name).block.call(request)
  end

  it 'keeps RfiDex traffic out of the general per-IP limit' do
    expect(discriminator('req/ip', '/v1/rfid/cache')).to be_nil
    expect(discriminator('req/ip', '/v1/events')).to eq('203.0.113.9')
  end

  it 'gives RfiDex its own, higher per-IP limit' do
    expect(discriminator('rfid/ip', '/v1/rfid/observations')).to eq('203.0.113.9')
    expect(discriminator('rfid/ip', '/v1/events')).to be_nil
    expect(Rack::Attack.throttles.fetch('rfid/ip').limit).to be > Rack::Attack.throttles.fetch('req/ip').limit
  end
end
