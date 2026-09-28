require 'rails_helper'

# Plan 5 Task 1: the durable, event-scoped facts RfiDex depends on. The
# uniqueness rules here are database constraints, not validations, because two
# stations can race each other; every raise below is wrapped in
# `requires_new: true` so PostgreSQL can recover inside the fixture transaction.
RSpec.describe 'RFID persistence' do
  let(:event) { create(:event) }
  let(:ticket) { create(:ticket, :paid, event: event) }
  let(:attrs) do
    { event: event, ticket: ticket, ticket_public_id: ticket.public_id,
      ticket_name: ticket.attendee_name, protocol: 'iso15693',
      uid_raw_hex: '3412CDAB500104E0', tag_key: '3412CDAB500104E0',
      mode: 'bind', captured_at: Time.current }
  end

  def uuid
    SecureRandom.uuid
  end

  def expect_unique_violation(&block)
    expect do
      Rfid::Binding.transaction(requires_new: true, &block)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe Rfid::Binding do
    it 'enforces one active tag at database level and permits history' do
      one = Rfid::Binding.create!(**attrs, operation_id: uuid)
      expect do
        Rfid::Binding.transaction(requires_new: true) do
          Rfid::Binding.create!(**attrs, operation_id: uuid)
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
      one.update!(revoked_at: Time.current, revocation_reason: 'Replacement')
      expect { Rfid::Binding.create!(**attrs, operation_id: uuid) }
        .to change(Rfid::Binding, :count).by(1)
    end

    it 'enforces one active sticker per ticket at database level' do
      Rfid::Binding.create!(**attrs, operation_id: uuid)

      expect_unique_violation do
        Rfid::Binding.create!(**attrs.merge(uid_raw_hex: 'AABB', tag_key: 'AABB'),
                              operation_id: uuid)
      end
    end

    it 'exposes active bindings only' do
      active = Rfid::Binding.create!(**attrs, operation_id: uuid)
      revoked = Rfid::Binding.create!(
        **attrs.merge(uid_raw_hex: 'AABB', tag_key: 'AABB'),
        operation_id: uuid, revoked_at: Time.current, revocation_reason: 'lost'
      )

      expect(event.rfid_bindings.active).to contain_exactly(active)
      expect(event.rfid_bindings).to contain_exactly(active, revoked)
    end

    it 'rejects an unknown protocol or mode' do
      expect(build(:rfid_binding, event: event, ticket: ticket, protocol: 'nfc'))
        .not_to be_valid
      expect(build(:rfid_binding, event: event, ticket: ticket, mode: 'write'))
        .not_to be_valid
    end

    it 'keeps the ticket snapshot when the ticket is hard deleted' do
      binding = Rfid::Binding.create!(**attrs, operation_id: uuid)
      public_id = ticket.public_id
      name = ticket.attendee_name

      ticket.delete

      binding.reload
      expect(binding.ticket_id).to be_nil, 'the FK must not block the delete'
      expect(binding.ticket_public_id).to eq(public_id)
      expect(binding.ticket_name).to eq(name)
    end

    it 'is scoped to its own event' do
      other_event = create(:event)
      other_ticket = create(:ticket, :paid, event: other_event)
      mine = Rfid::Binding.create!(**attrs, operation_id: uuid)
      theirs = Rfid::Binding.create!(**attrs.merge(event: other_event, ticket: other_ticket,
                                                   ticket_public_id: other_ticket.public_id),
                                     operation_id: uuid)

      expect(event.rfid_bindings).to contain_exactly(mine)
      expect(Rfid::Binding.where(tag_key: '3412CDAB500104E0')).to contain_exactly(mine, theirs)
    end
  end

  describe 'operation replay records' do
    it 'keeps one desk-scan operation per event and operation id' do
      operation_id = uuid
      Rfid::DeskOperation.create!(event: event, operation_id: operation_id,
                                  request_digest: 'a', original_response: { 'ok' => true })

      expect do
        Rfid::DeskOperation.transaction(requires_new: true) do
          Rfid::DeskOperation.create!(event: event, operation_id: operation_id,
                                      request_digest: 'b', original_response: {})
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'keeps the same operation id usable in another event' do
      operation_id = uuid
      Rfid::DeskOperation.create!(event: event, operation_id: operation_id,
                                  request_digest: 'a', original_response: {})

      expect do
        Rfid::DeskOperation.create!(event: create(:event), operation_id: operation_id,
                                    request_digest: 'a', original_response: {})
      end.to change(Rfid::DeskOperation, :count).by(1)
    end

    it 'keeps one binding operation per event and operation id' do
      operation_id = uuid
      Rfid::BindingOperation.create!(event: event, operation_id: operation_id,
                                     request_digest: 'a', original_response: {})

      expect do
        Rfid::BindingOperation.transaction(requires_new: true) do
          Rfid::BindingOperation.create!(event: event, operation_id: operation_id,
                                         request_digest: 'a', original_response: {})
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe Rfid::Station do
    it 'is unique per event by opaque station key and validates kind' do
      station = Rfid::Station.create!(event: event, station_key: 'desk-contract', name: 'Desk',
                                      kind: 'desk')
      expect(station.uid_rule).to eq('as_is')
      expect(station.role).to be_nil

      # The index is the arbitration; the validation is only the readable error.
      expect(build(:rfid_station, event: event, station_key: 'desk-contract')).not_to be_valid

      expect do
        Rfid::Station.transaction(requires_new: true) do
          Rfid::Station.insert_all!(
            [{ event_id: event.id, station_key: 'desk-contract', kind: 'desk',
               uid_rule: 'as_is', created_at: Time.current, updated_at: Time.current }]
          )
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)

      expect do
        Rfid::Station.create!(event: create(:event), station_key: 'desk-contract', kind: 'desk')
      end.to change(Rfid::Station, :count).by(1)
    end

    it 'rejects an unknown kind, role or uid rule' do
      expect(build(:rfid_station, event: event, kind: 'kiosk')).not_to be_valid
      expect(build(:rfid_station, event: event, role: 'sideways')).not_to be_valid
      expect(build(:rfid_station, event: event, uid_rule: 'flipped')).not_to be_valid
    end
  end

  describe Rfid::Observation do
    let(:station) { Rfid::Station.create!(event: event, station_key: 'gate-in', kind: 'gate') }
    let(:observation_attrs) do
      { event: event, station: station, role: 'entry', protocol: 'iso15693',
        uid_raw_hex: '3412CDAB500104E0', tag_key: '3412CDAB500104E0',
        captured_at: Time.current, recorded_at: Time.current, outcome: 'unknown_tag',
        request_digest: 'a', original_response: { 'outcome' => 'unknown_tag' } }
    end

    it 'keeps one result per station and delivery id' do
      delivery_id = uuid
      Rfid::Observation.create!(**observation_attrs, delivery_id: delivery_id)

      expect do
        Rfid::Observation.transaction(requires_new: true) do
          Rfid::Observation.create!(**observation_attrs, delivery_id: delivery_id)
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'stores duplicate device sequences without a second row conflict' do
      Rfid::Observation.create!(**observation_attrs, delivery_id: uuid, device_record_seq: 77)

      expect do
        Rfid::Observation.create!(**observation_attrs.merge(outcome: 'possible_duplicate'),
                                  delivery_id: uuid, device_record_seq: 77)
      end.to change(Rfid::Observation, :count).by(1)
    end

    it 'rejects an unknown outcome' do
      expect(build(:rfid_observation, event: event, station: station, outcome: 'maybe'))
        .not_to be_valid
    end
  end

  describe Rfid::Visit do
    let(:station) { Rfid::Station.create!(event: event, station_key: 'gate-in', kind: 'gate') }
    let(:observation) { create(:rfid_observation, event: event, station: station, outcome: 'accepted') }

    it 'keys a visit by its entry observation and keeps one row per entry' do
      Rfid::Visit.create!(event: event, ticket: ticket, ticket_public_id: ticket.public_id,
                          entry_observation: observation, entry_at: Time.current)

      expect do
        Rfid::Visit.transaction(requires_new: true) do
          Rfid::Visit.create!(event: event, ticket: ticket,
                              ticket_public_id: ticket.public_id,
                              entry_observation: observation, entry_at: Time.current)
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe Rfid::Correction do
    let(:station) { Rfid::Station.create!(event: event, station_key: 'gate-in', kind: 'gate') }
    let(:observation) { create(:rfid_observation, event: event, station: station, outcome: 'accepted') }

    it 'records the actor, reason and target observation' do
      actor = create(:user)
      correction = Rfid::Correction.create!(
        event: event, actor: actor, entry_observation: observation, kind: 'manual_exit',
        exit_at: 1.hour.from_now, reason: 'Guest left through the service door'
      )

      expect(correction.entry_observation).to eq(observation)
      expect(correction.actor).to eq(actor)
    end
  end

  describe 'event configuration' do
    it 'defaults to bind mode with check-in not required' do
      fresh = create(:event)
      expect(fresh.rfid_mode).to eq('bind')
      expect(fresh.rfid_require_check_in).to be(false)
    end

    it 'validates the rfid mode' do
      expect(build(:event, rfid_mode: 'sticker')).not_to be_valid
      expect(build(:event, rfid_mode: 'write')).to be_valid
    end

    it 'exposes require_check_in through the reader the device API uses' do
      expect(create(:event, rfid_require_check_in: true).rfid_require_check_in).to be(true)
    end
  end

  describe 'scan log operation ids' do
    it 'keeps an operation id unique when present and nullable otherwise' do
      operation_id = uuid
      ScanLog.create!(event: event, scannable: ticket, scanned_at: Time.current,
                      source: :rfid_desk, operation_id: operation_id)

      expect do
        ScanLog.transaction(requires_new: true) do
          ScanLog.create!(event: event, scannable: ticket, scanned_at: Time.current,
                          source: :rfid_desk, operation_id: operation_id)
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)

      expect do
        ScanLog.create!(event: event, scannable: ticket, scanned_at: Time.current,
                        source: :rfid_desk, operation_id: nil)
      end.to change(ScanLog, :count).by(1)
    end

    it 'appends rfid_desk without renumbering the existing sources' do
      expect(ScanLog.sources).to include(
        'staff_scan' => 0, 'self_check_in' => 1, 'kiosk' => 2, 'reprint' => 3,
        'rfid_desk' => 4
      )
    end
  end
end
