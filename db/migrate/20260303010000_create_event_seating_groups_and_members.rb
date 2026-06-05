class CreateEventSeatingGroupsAndMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :event_seating_groups do |t|
      t.references :event, null: false, foreign_key: true
      t.references :plan, null: true, foreign_key: true
      t.integer :scope, null: false, default: 0
      t.string :name, null: false
      t.text :notes

      t.timestamps
    end

    add_index :event_seating_groups, [:event_id, :scope]
    add_index :event_seating_groups, [:plan_id, :scope]

    create_table :event_seating_group_members do |t|
      t.references :event_seating_group, null: false, foreign_key: true
      t.string :participant_type, null: false
      t.bigint :participant_id, null: false

      t.timestamps
    end

    add_index :event_seating_group_members,
      [:participant_type, :participant_id],
      unique: true,
      name: "index_event_seating_group_members_on_participant_unique"
    add_index :event_seating_group_members,
      [:event_seating_group_id, :participant_type],
      name: "index_event_seating_group_members_on_group_and_type"

    add_column :table_assignments, :notes, :text
  end
end
