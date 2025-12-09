class CreateEventPrintingServices < ActiveRecord::Migration[8.0]
  def change
    create_table :event_printing_services do |t|
      t.references :event, null: false, foreign_key: true
      t.references :printing_service, null: false, foreign_key: true

      t.timestamps
    end
  end
end
