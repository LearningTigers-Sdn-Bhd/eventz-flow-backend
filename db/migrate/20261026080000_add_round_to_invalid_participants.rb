class AddRoundToInvalidParticipants < ActiveRecord::Migration[8.0]
  def change
    # Which draw (click of Draw) picked this winner when gifts are off.
    # NULL for winners saved before rounds existed.
    add_column :invalid_participants, :round, :integer
    add_index :invalid_participants, %i[lucky_draw_session_id round],
              name: 'index_invalid_participants_on_session_id_and_round'
    add_check_constraint :invalid_participants, 'round IS NULL OR round > 0',
                         name: 'chk_invalid_participants_round_positive'
  end
end
