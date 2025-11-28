class CreateEventExhibitionContractors < ActiveRecord::Migration[8.0]
  def change
    create_table :event_exhibition_contractors do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.references :exhibition_contractor_profile, null: false, foreign_key: true

      t.timestamps
    end
    add_index :event_exhibition_contractors, :event_id, unique: true
  end
end
