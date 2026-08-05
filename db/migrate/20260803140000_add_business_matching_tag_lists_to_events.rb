class AddBusinessMatchingTagListsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :business_matching_offering_tags, :jsonb, default: [], null: false
    add_column :events, :business_matching_interest_tags, :jsonb, default: [], null: false
  end
end
