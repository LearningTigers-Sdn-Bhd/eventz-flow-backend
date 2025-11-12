class CreateGroupAffiliates < ActiveRecord::Migration[8.0]
  def change
    create_table :group_affiliates do |t|
      t.references :group, null: false, foreign_key: true, index: { unique: true }
      t.references :vendor, null: false, foreign_key: { to_table: :users }, index: true

      t.timestamps
    end
  end
end
