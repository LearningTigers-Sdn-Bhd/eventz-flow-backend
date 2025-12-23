class AddUseBusinessMatchingToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_business_matching, :boolean, default: false
  end
end
