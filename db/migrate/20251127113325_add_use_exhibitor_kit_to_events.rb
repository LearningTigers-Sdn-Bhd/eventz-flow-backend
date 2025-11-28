class AddUseExhibitorKitToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_exhibitor_kit, :boolean, default: false, null: false
  end
end
