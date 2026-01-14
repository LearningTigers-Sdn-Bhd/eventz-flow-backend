class CreateResourceChangelogs < ActiveRecord::Migration[8.0]
  def change
    create_table :resource_changelogs do |t|
      # References
      t.references :resource, null: false, foreign_key: true
      t.references :changed_by_user, null: false, foreign_key: { to_table: :users }

      # Snapshot of resource fields at time of change
      t.string :title
      t.text :article
      t.string :slug
      t.string :meta_description
      t.bigint :resource_topic_id
      t.bigint :resource_category_id
      t.bigint :resource_media_type_id
      t.integer :status
      t.datetime :published_at
      t.integer :view_counts
      t.integer :priority
      t.boolean :is_gated
      t.boolean :is_official
      t.text :rejection_reason

      # When the change was recorded
      t.datetime :changed_at, null: false

      t.timestamps
    end

    add_index :resource_changelogs, :changed_at
  end
end
