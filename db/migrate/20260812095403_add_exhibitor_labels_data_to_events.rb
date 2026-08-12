class AddExhibitorLabelsDataToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :exhibitor_labels_data, :jsonb, default: {}
  end
end
