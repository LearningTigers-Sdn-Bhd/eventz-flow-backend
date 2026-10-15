class CreateVehicleRegistrations < ActiveRecord::Migration[8.0]
  # Guarded with if_not_exists so a database that already has these objects
  # (e.g. a staging DB that ran an earlier version of this migration under a
  # different version number) can still migrate. A DB that already recorded
  # this version never re-runs it, so production is unaffected.
  def change
    create_table :vehicle_registrations, if_not_exists: true do |t|
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
              name: 'idx_vehicle_registrations_event_plate',
              if_not_exists: true
    add_reference :tickets, :vehicle_registration, foreign_key: true, index: true, if_not_exists: true
  end
end
