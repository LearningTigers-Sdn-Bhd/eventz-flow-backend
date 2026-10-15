class AddDeletedAtToVehicleRegistrations < ActiveRecord::Migration[8.0]
  def change
    add_column :vehicle_registrations, :deleted_at, :datetime
    add_index :vehicle_registrations, :deleted_at

    # Plate uniqueness should only apply to live vehicles — archiving frees
    # the plate so the same car can be re-registered later without restoring
    # the old row first.
    remove_index :vehicle_registrations, name: 'idx_vehicle_registrations_event_plate'
    add_index :vehicle_registrations, %i[event_id normalized_plate],
              unique: true,
              where: 'deleted_at IS NULL',
              name: 'idx_vehicle_registrations_event_plate'
  end
end
