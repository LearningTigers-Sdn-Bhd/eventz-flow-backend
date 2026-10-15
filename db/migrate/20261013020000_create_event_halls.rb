# frozen_string_literal: true

class CreateEventHalls < ActiveRecord::Migration[8.0]
  def change
    create_table :event_halls do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.string :floor
      # Venue id on the external people-counter service. Not unique: a physical
      # hall is reused across events.
      t.bigint :counter_venue_id
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :event_halls, %i[event_id name], unique: true
    add_index :event_halls, :counter_venue_id
  end
end
