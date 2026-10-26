class AddGiftDrawOptions < ActiveRecord::Migration[8.0]
  def change
    # How the next gift is chosen: by the gift order, or at random among open gifts.
    add_column :lucky_draw_sessions, :gift_pick, :string, null: false, default: 'in_order'
    # One click gives every open gift one winner (a "round") instead of filling one gift.
    add_column :lucky_draw_sessions, :round_sweep, :boolean, null: false, default: false
    # Held back until every other gift is done (the grand prize).
    add_column :gifts, :draw_last, :boolean, null: false, default: false

    # Which sweep round picked this winner. NULL for winners drawn gift by gift.
    add_column :gift_winners, :round, :integer
    add_check_constraint :gift_winners, 'round IS NULL OR round > 0',
                         name: 'chk_gift_winners_round_positive'
  end
end
