class CreateGroupMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :group_members do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :has_manager_access, default: false, null: false

      t.timestamps
    end

    add_index :group_members, [:group_id, :user_id], unique: true
  end
end
