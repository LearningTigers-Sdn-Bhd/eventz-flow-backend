class AddEventIdToExportLogs < ActiveRecord::Migration[8.0]
  def change
    add_reference :export_logs, :event, null: false, foreign_key: true
  end
end
