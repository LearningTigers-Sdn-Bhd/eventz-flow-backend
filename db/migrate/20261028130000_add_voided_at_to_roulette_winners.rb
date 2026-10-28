class AddVoidedAtToRouletteWinners < ActiveRecord::Migration[8.0]
  def change
    # An unclaimed prize: the winner stays recorded (and, when the session is not
    # multiple, cannot spin again) but the prize goes back in stock. NULL = valid.
    add_column :roulette_winners, :voided_at, :datetime
  end
end
