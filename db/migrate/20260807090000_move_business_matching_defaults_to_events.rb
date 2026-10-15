class MoveBusinessMatchingDefaultsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :business_matching_default_start_date, :date
    add_column :events, :business_matching_default_end_date, :date
    add_column :events, :business_matching_default_hours, :jsonb, default: [{ 'start_time' => '09:00', 'end_time' => '17:00' }], null: false
    add_column :events, :business_matching_hours_editable_default, :boolean, default: true, null: false

    drop_table :system_settings do |t|
      t.jsonb :business_matching_default_hours, default: [{ 'start_time' => '09:00', 'end_time' => '17:00' }], null: false
      t.boolean :business_matching_hours_editable_default, default: true, null: false
      t.timestamps
    end
  end
end
