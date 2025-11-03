class CreateExportLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :export_logs do |t|
      t.string :type
      t.string :sheet_path

      t.timestamps
    end

    add_index :export_logs, [:type, :created_at]
  end
end
