class AddLuckyDrawCollectionDetails < ActiveRecord::Migration[8.0]
  def change
    %i[gift_winners invalid_participants].each do |table|
      add_column table, :claimed_at, :datetime
      add_column table, :gift_taken, :string, limit: 500
      add_column table, :collection_updated_at, :datetime
    end
  end
end
