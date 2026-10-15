class AddHoursEditableAndSystemSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :system_settings do |t|
      t.jsonb :business_matching_default_hours, default: [{ 'start_time' => '09:00', 'end_time' => '17:00' }], null: false
      t.boolean :business_matching_hours_editable_default, default: true, null: false
      t.timestamps
    end

    add_column :business_matching_sessions, :hours_editable, :boolean
    add_column :business_host_assignments, :hours_editable_override, :boolean
  end
end
