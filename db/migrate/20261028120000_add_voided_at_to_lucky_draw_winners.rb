class AddVoidedAtToLuckyDrawWinners < ActiveRecord::Migration[8.0]
  def change
    # A voided winner (no-show) stays in the table, so they cannot win again
    # and the history is kept, but they stop counting toward the gift. NULL = valid.
    add_column :gift_winners, :voided_at, :datetime
    add_column :invalid_participants, :voided_at, :datetime
  end
end
