class CreateTableAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :table_assignments do |t|
      t.references :ticket, null: false, foreign_key: true, index: { unique: true }
      t.references :plan_object, null: false, foreign_key: true

      t.timestamps
    end
  end
end
