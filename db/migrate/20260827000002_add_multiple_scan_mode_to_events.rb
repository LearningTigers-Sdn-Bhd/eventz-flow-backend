class AddMultipleScanModeToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :multiple_scan_mode, :integer, null: false, default: 0
  end
end
