# frozen_string_literal: true

class CreatePeopleCounterConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :people_counter_connections do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.string :base_url, null: false
      # Encrypted at rest (ActiveRecord encryption), same as the payment gateway secrets.
      t.text :api_key, null: false
      t.timestamps
    end
  end
end
