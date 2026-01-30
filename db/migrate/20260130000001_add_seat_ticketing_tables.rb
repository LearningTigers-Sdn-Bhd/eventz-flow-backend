class AddSeatTicketingTables < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_seat_ticketing, :boolean, default: false, null: false

    create_table :event_seat_sessions do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :status, null: false, default: 0
      t.string :location
      t.integer :order, default: 0
      t.datetime :start_datetime
      t.datetime :end_datetime
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :event_seat_sessions, :deleted_at

    create_table :event_seat_venues do |t|
      t.references :event_seat_session, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :row
      t.integer :column
      t.timestamps
    end

    create_table :event_seat_sections do |t|
      t.references :event_seat_venue, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :prize, precision: 8, scale: 2, default: 0.0
      t.integer :seat_row
      t.integer :seat_column
      t.integer :row_span
      t.integer :col_span
      t.timestamps
    end

    create_table :event_ticket_seats do |t|
      t.references :event_seat_section, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :extra_price, precision: 8, scale: 2, default: 0.0
      t.integer :row_set
      t.integer :col_set
      t.references :ticket, foreign_key: true
      t.references :visitor, foreign_key: true
      t.timestamps
    end
  end
end
