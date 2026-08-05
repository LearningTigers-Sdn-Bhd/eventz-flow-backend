class CreateBusinessMatchingParticipants < ActiveRecord::Migration[7.1]
  def change
    create_table :business_matching_participants do |t|
      t.references :event, null: false, foreign_key: true
      t.references :registerable, polymorphic: true, null: false
      t.string :magic_token, null: false
      t.jsonb :profile_data, default: {}, null: false
      t.timestamps
    end

    add_index :business_matching_participants, :magic_token, unique: true
    add_index :business_matching_participants, [:event_id, :registerable_type, :registerable_id], unique: true, name: 'index_bm_participants_uniqueness'

    # Add columns to availabilities and bookings for unified participants matching
    add_reference :business_matching_availabilities, :business_matching_participant, foreign_key: true, index: { name: 'index_bm_availabilities_on_participant_id' }
    
    add_reference :business_matching_bookings, :requester_participant, foreign_key: { to_table: :business_matching_participants }, type: :bigint, index: { name: 'index_bm_bookings_on_requester_participant_id' }
    add_reference :business_matching_bookings, :receiver_participant, foreign_key: { to_table: :business_matching_participants }, type: :bigint, index: { name: 'index_bm_bookings_on_receiver_participant_id' }

    # Add index for preventing double booking between participants on the same slot
    add_index :business_matching_bookings, [:receiver_participant_id, :booking_date, :booking_time], name: 'index_bm_bookings_receiver_time_unique', unique: true, where: "status != 'Cancelled'"
  end
end
