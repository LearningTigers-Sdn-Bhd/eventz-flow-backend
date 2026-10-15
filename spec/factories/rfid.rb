FactoryBot.define do
  factory :rfid_station, class: 'Rfid::Station' do
    event
    sequence(:station_key) { |n| "station-#{n}" }
    name { 'Gate' }
    kind { 'gate' }
  end

  factory :rfid_binding, class: 'Rfid::Binding' do
    event
    ticket
    ticket_public_id { ticket.public_id }
    ticket_name { ticket.attendee_name }
    protocol { 'iso15693' }
    sequence(:uid_raw_hex) { |n| format('%016X', n + 1) }
    tag_key { uid_raw_hex }
    mode { 'bind' }
    captured_at { Time.current }
    operation_id { SecureRandom.uuid }
  end

  factory :rfid_observation, class: 'Rfid::Observation' do
    event
    association :station, factory: :rfid_station
    delivery_id { SecureRandom.uuid }
    role { 'entry' }
    protocol { 'iso15693' }
    uid_raw_hex { '3412CDAB500104E0' }
    tag_key { uid_raw_hex }
    captured_at { Time.current }
    recorded_at { Time.current }
    outcome { 'unknown_tag' }
    request_digest { 'digest' }
    original_response { {} }
  end

  factory :rfid_desk_operation, class: 'Rfid::DeskOperation' do
    event
    operation_id { SecureRandom.uuid }
    request_digest { 'digest' }
    original_response { {} }
  end
end
