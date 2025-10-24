class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.boolean :multiple_scans, default: false, null: false
      t.datetime :start_date
      t.datetime :end_date
      t.string :webhook_url
      t.jsonb :labels_data, default: {}
      t.boolean :visibility, default: true, null: false

      t.timestamps
    end
  end
end
