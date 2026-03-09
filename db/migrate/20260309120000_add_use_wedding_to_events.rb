class AddUseWeddingToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_wedding, :boolean, null: false, default: false
  end
end
