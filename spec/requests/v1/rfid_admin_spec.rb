require 'rails_helper'

# Org-owner clean-up: delete stations/bindings/readings, edit a binding,
# dismiss anomalies. Headcount and visits must match what is left.
RSpec.describe 'V1::Rfid admin actions', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:event) { create(:event, use_api_access: true) }
  let(:checked_in_at) { Time.zone.parse('2026-09-26T08:00:00Z') }
  let(:ticket) do
    create(:ticket, :paid, :checked_in, event: event, attendee_name: 'Ahmad Bin Ali',
                                       check_in_at: checked_in_at)
  end
  let(:other_ticket) do
    create(:ticket, :paid, :checked_in, event: event, attendee_name: 'Siti Aminah',
                                       check_in_at: checked_in_at)
  end
  let(:tag) { '3412CDAB500104E0' }
  let(:base) { Time.zone.parse('2026-09-26T09:00:00Z') }
  let(:headers) { auth_headers(owner) }
  let(:root) { "/v1/events/#{event.id}/rfid" }
  let!(:gate) { Rfid::Station.create!(event: event, station_key: 'gate-1', kind: 'gate') }

  # `event` keeps associations loaded by the services; read the database.
  def fresh
    Event.find(event.id)
  end

  def body
    JSON.parse(response.body)
  end

  def bind!(for_ticket: ticket, uid: tag, at: base - 1.hour)
    Rfid::Binding.create!(event: event, ticket: for_ticket, ticket_public_id: for_ticket.public_id,
                          ticket_name: for_ticket.attendee_name, protocol: 'iso15693',
                          uid_raw_hex: uid, tag_key: uid, mode: 'bind', captured_at: at,
                          operation_id: SecureRandom.uuid)
  end

  def read!(role, at, uid: tag, station: gate)
    item = Rfid::Observe::Item.new(delivery_id: SecureRandom.uuid, role: role,
                                   protocol: 'iso15693', uid_raw_hex: uid, tag_key: uid,
                                   captured_at: at)
    Rfid::Observe.call(event: event, station: station, items: [item])
  end

  describe 'authorization' do
    let!(:binding) { bind! }

    it 'refuses everyone but the org owner' do
      calls = [
        [:delete, "#{root}/stations/#{gate.id}", {}],
        [:patch, "#{root}/bindings/#{binding.id}", { tag_key: 'AABB' }],
        [:delete, "#{root}/bindings/#{binding.id}", {}],
        [:post, "#{root}/anomalies/dismiss", { all: true }],
        [:delete, "#{root}/anomalies", { all: true }]
      ]
      [auth_headers(organizer), auth_headers(create(:user, :member))].each do |who|
        calls.each do |verb, path, params|
          public_send(verb, path, params: params, headers: who, as: :json)
          expect(response).to have_http_status(:forbidden), "#{verb} #{path}"
        end
      end

      expect(Rfid::Station.exists?(gate.id)).to be true
      expect(Rfid::Binding.exists?(binding.id)).to be true
    end
  end

  describe 'DELETE station' do
    it 'removes the station, its readings and the visits built from them' do
      bind!
      other_gate = Rfid::Station.create!(event: event, station_key: 'gate-2', kind: 'gate')
      read!('entry', base)
      read!('exit', base + 1.hour, station: other_gate)

      delete "#{root}/stations/#{gate.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Rfid::Station.exists?(gate.id)).to be false
      expect(fresh.rfid_observations.pluck(:station_id)).to eq([other_gate.id])
      expect(fresh.rfid_visits.count).to eq(0)
      get "#{root}/summary", headers: headers
      expect(body['headcount']).to eq(0)
    end

    it 'answers 404 for a station of another event' do
      foreign = Rfid::Station.create!(event: create(:event), station_key: 'x', kind: 'gate')

      delete "#{root}/stations/#{foreign.id}", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE binding' do
    it 'removes it and makes its earlier readings unknown' do
      binding = bind!
      read!('entry', base)
      expect(fresh.rfid_visits.count).to eq(1)

      delete "#{root}/bindings/#{binding.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Rfid::Binding.exists?(binding.id)).to be false
      expect(fresh.rfid_observations.sole.outcome).to eq('unknown_tag')
      expect(fresh.rfid_visits.count).to eq(0)
    end
  end

  describe 'PATCH binding' do
    let!(:binding) { bind! }

    it 'moves the sticker to another ticket and re-measures its readings' do
      read!('entry', base)

      patch "#{root}/bindings/#{binding.id}", params: { ticket_public_id: other_ticket.public_id },
                                              headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['binding']['ticket_name']).to eq('Siti Aminah')
      expect(fresh.rfid_visits.sole.ticket_public_id).to eq(other_ticket.public_id)
    end

    it 'changes the sticker key' do
      patch "#{root}/bindings/#{binding.id}", params: { tag_key: 'aabbccdd11223344' },
                                              headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(binding.reload.tag_key).to eq('AABBCCDD11223344')
      expect(binding.uid_raw_hex).to eq('AABBCCDD11223344')
    end

    it 'refuses a sticker already linked, and a ticket that has one' do
      bind!(for_ticket: other_ticket, uid: 'AABBCCDD11223344')

      patch "#{root}/bindings/#{binding.id}", params: { tag_key: 'AABBCCDD11223344' },
                                              headers: headers, as: :json
      expect(response).to have_http_status(:conflict)

      patch "#{root}/bindings/#{binding.id}", params: { ticket_public_id: other_ticket.public_id },
                                              headers: headers, as: :json
      expect(response).to have_http_status(:conflict)
    end

    it 'refuses a bad key, an unknown, unpaid or cancelled ticket, and an empty change' do
      unpaid = create(:ticket, event: event)
      cases = [{ tag_key: 'xyz' }, { ticket_public_id: SecureRandom.uuid },
               { ticket_public_id: unpaid.public_id }, {}]
      statuses = cases.map do |params|
        patch "#{root}/bindings/#{binding.id}", params: params, headers: headers, as: :json
        response.status
      end

      expect(statuses).to eq([422, 404, 422, 422])
      expect(binding.reload.tag_key).to eq(tag)
    end

    it 'does not edit a revoked binding' do
      binding.update!(revoked_at: Time.current)

      patch "#{root}/bindings/#{binding.id}", params: { tag_key: 'AABB' }, headers: headers,
                                              as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'anomalies' do
    before do
      bind!
      read!('exit', base)                        # unmatched exit -> anomaly
      read!('entry', base + 1.hour, uid: 'FF' * 8) # unknown tag -> anomaly
      read!('entry', base + 2.hours)             # fine
    end

    def anomaly_count
      get "#{root}/summary", headers: headers
      body['anomaly_count']
    end

    it 'dismisses selected readings without deleting them' do
      expect(anomaly_count).to eq(2)
      id = fresh.rfid_observations.find_by(outcome: 'unknown_tag').id

      post "#{root}/anomalies/dismiss", params: { ids: [id] }, headers: headers, as: :json

      expect(body['affected']).to eq(1)
      expect(anomaly_count).to eq(1)
      expect(fresh.rfid_observations.count).to eq(3)
    end

    it 'dismisses every anomaly' do
      post "#{root}/anomalies/dismiss", params: { all: true }, headers: headers, as: :json

      expect(body['affected']).to eq(2)
      expect(anomaly_count).to eq(0)
      expect(fresh.rfid_observations.count).to eq(3)
    end

    it 'deletes selected readings, dismissed or not' do
      id = fresh.rfid_observations.find_by(outcome: 'unknown_tag').id
      post "#{root}/anomalies/dismiss", params: { ids: [id] }, headers: headers, as: :json

      delete "#{root}/anomalies", params: { ids: [id] }, headers: headers, as: :json

      expect(body['affected']).to eq(1)
      expect(fresh.rfid_observations.count).to eq(2)
    end

    it 'deletes every anomaly and keeps the good reading and its visit' do
      delete "#{root}/anomalies", params: { all: true }, headers: headers, as: :json

      expect(body['affected']).to eq(2)
      expect(fresh.rfid_observations.pluck(:outcome)).to eq(['accepted'])
      expect(fresh.rfid_visits.count).to eq(1)
    end

    it 'refuses ids that are not anomalies, and a call with no selection' do
      good = fresh.rfid_observations.find_by(outcome: 'accepted').id

      delete "#{root}/anomalies", params: { ids: [good] }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post "#{root}/anomalies/dismiss", params: {}, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(fresh.rfid_observations.count).to eq(3)
    end
  end
end
