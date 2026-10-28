class AddTagsToExhibitorKits < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :exhibitor_tags_per_kit, :integer, default: 2, null: false

    change_table :exhibitor_kits, bulk: true do |t|
      t.integer :tags_collected, default: 0, null: false
      t.datetime :tags_collected_at
      t.references :tags_collected_by, foreign_key: { to_table: :users }, null: true
    end
  end
end
