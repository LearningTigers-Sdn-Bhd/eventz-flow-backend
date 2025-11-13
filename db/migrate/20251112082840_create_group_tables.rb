class CreateGroupTables < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :groups, :name

    create_table :group_members do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :has_manager_access, default: false, null: false

      t.timestamps
    end

    add_index :group_members, [:group_id, :user_id], unique: true

    create_table :group_affiliates do |t|
      t.references :group, null: false, foreign_key: true, index: { unique: true }
      t.references :vendor, null: false, foreign_key: { to_table: :users }, index: true

      t.timestamps
    end
  end
end
