class CreateVehicleRegistrations < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicle_registrations do |t|
      t.references :event, null: false, foreign_key: true
      t.references :registration_form, null: false, foreign_key: true
      t.references :base_ticket_type, null: false, foreign_key: { to_table: :ticket_types }
      t.string :plate, null: false
      t.string :normalized_plate, null: false
      t.timestamps
    end

    add_index :vehicle_registrations,
              %i[event_id normalized_plate],
              unique: true,
              name: 'idx_vehicle_registrations_event_plate'
    add_reference :tickets, :vehicle_registration, foreign_key: true, index: true
  end
end
