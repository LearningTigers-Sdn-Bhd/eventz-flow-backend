class AddDeletedAtToVehicleRegistrations < ActiveRecord::Migration[8.0]
  def change
    # Guarded so a DB that already has these objects can still migrate; a DB
    # that recorded this version never re-runs it.
    add_column :vehicle_registrations, :deleted_at, :datetime, if_not_exists: true
    add_index :vehicle_registrations, :deleted_at, if_not_exists: true

    # Plate uniqueness should only apply to live vehicles — archiving frees
    # the plate so the same car can be re-registered later without restoring
    # the old row first.
    remove_index :vehicle_registrations, name: 'idx_vehicle_registrations_event_plate', if_exists: true
    add_index :vehicle_registrations, %i[event_id normalized_plate],
              unique: true,
              where: 'deleted_at IS NULL',
              name: 'idx_vehicle_registrations_event_plate',
              if_not_exists: true
  end
end
