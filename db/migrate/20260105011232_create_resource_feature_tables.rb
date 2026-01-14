# db/migrate/20260105011232_create_resource_feature_tables.rb
class CreateResourceFeatureTables < ActiveRecord::Migration[7.0]
  def change
    # Tracks which users are authorized to create content
    create_table :resource_write_permissions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :is_official, default: false
      t.integer :status, default: 0 # 0: Base, 1: Partnership
      t.timestamps
    end

    # Defines content topics (e.g., "AI Content", "Event Technology")
    create_table :resource_topics do |t|
      t.string :name
      t.string :slug, null: false
      t.text :description
      t.string :logo
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :resource_topics, :slug, unique: true
    add_index :resource_topics, :deleted_at

    # Broad classification for resources
    create_table :resource_categories do |t|
      t.string :name
      t.string :slug, null: false
      t.text :description
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :resource_categories, :slug, unique: true
    add_index :resource_categories, :deleted_at

    # Defines the format of the resource (e.g., "Article", "E-Book")
    create_table :resource_media_types do |t|
      t.string :name
      t.string :slug, null: false
      t.text :description
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :resource_media_types, :slug, unique: true
    add_index :resource_media_types, :deleted_at

    # The main table storing the content of the resources
    create_table :resources do |t|
      t.string :title
      t.text :article
      t.string :slug, null: false
      t.string :meta_description
      t.references :user, null: false, foreign_key: true # Author
      t.references :resource_topic, null: false, foreign_key: true
      t.references :resource_category, null: false, foreign_key: true
      t.references :resource_media_type, null: false, foreign_key: true
      t.integer :status, default: 0 # 0: Draft, 1: In Review, 2: Published
      t.datetime :published_at
      t.datetime :deleted_at
      t.integer :view_counts, default: 0
      t.integer :priority, default: 10
      t.boolean :is_gated, default: false
      t.boolean :is_official, default: false
      t.text :rejection_reason
      t.timestamps
    end
    add_index :resources, :slug, unique: true
    add_index :resources, :deleted_at

    # Captures information from visitors who access gated resources
    create_table :resource_leads do |t|
      t.string :email
      t.string :name
      t.string :phone
      t.string :company_name
      t.string :state
      t.string :country
      t.string :job_title
      t.string :ip_address
      t.datetime :accessed_at
      t.timestamps
    end
  end
end