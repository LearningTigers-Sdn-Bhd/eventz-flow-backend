class CreateBusinessHostAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :business_host_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.string :business_matching_event_id

      t.timestamps
    end
  end
end
