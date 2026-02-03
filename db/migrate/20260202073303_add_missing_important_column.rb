class AddMissingImportantColumn < ActiveRecord::Migration[8.0]
  def change
    add_column :event_seat_venues, :aspect_ratio, :string
    add_column :event_seat_sessions, :public_id, :string
    add_column :event_seat_sessions, :slug, :string

    add_index :event_seat_sessions, :public_id, unique: true
    add_index :event_seat_sessions, :slug, unique: true
  end
end
