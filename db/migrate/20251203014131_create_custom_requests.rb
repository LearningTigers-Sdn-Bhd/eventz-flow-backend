class CreateCustomRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_requests do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true
      t.text :description
      t.integer :quantity
      t.integer :status
      t.decimal :resolved_price, precision: 8, scale: 2
      t.text :response_notes

      t.timestamps
    end
  end
end
