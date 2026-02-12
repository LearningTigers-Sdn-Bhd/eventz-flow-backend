class CreateEventSeatGroupsAndSyncTicketTypes < ActiveRecord::Migration[8.0]
  def change
    # 1. New Table for Seat Groups
    create_table :event_seat_groups do |t|
      t.references :event_seat_section, null: false, foreign_key: true
      t.references :ticket_type, null: true, foreign_key: true
      t.string :name, null: false
      t.decimal :extra_price, precision: 8, scale: 2, default: 0.0
      t.string :color, default: 'green'
      t.timestamps
    end

    # 2. Join Table for Seat to Group Assignment
    create_table :event_seat_group_assignments do |t|
      t.references :event_seat_group, null: false, foreign_key: { to_table: :event_seat_groups }, index: { name: 'idx_seat_group_assignment_on_group_id' }
      t.references :event_ticket_seat, null: false, foreign_key: true, index: { name: 'idx_seat_group_assignment_on_seat_id' }
      t.timestamps
    end

    # Ensure a seat is only in one group at a time
    add_index :event_seat_group_assignments, :event_ticket_seat_id, unique: true, name: 'idx_unique_seat_assignment'

    # 3. Add Sync Columns to TicketType
    add_column :ticket_types, :seat_ticketing_type, :integer
    add_column :ticket_types, :seat_ticketing_source_id, :bigint
    add_index :ticket_types, [:seat_ticketing_type, :seat_ticketing_source_id], name: 'idx_ticket_types_on_seat_ticketing'

    # 4. Add ticket_type_id and color to existing Seat Ticketing tables
    add_reference :event_seat_sections, :ticket_type, null: true, foreign_key: true
        add_column :event_seat_sections, :color, :string, default: 'blue'
        add_reference :event_ticket_seats, :ticket_type, null: true, foreign_key: true
    
        # 5. Prevent Overlapping Seats
        add_index :event_ticket_seats, [:event_seat_section_id, :row_set, :col_set], unique: true, name: 'idx_event_ticket_seats_on_section_coords'
      end
    end
    