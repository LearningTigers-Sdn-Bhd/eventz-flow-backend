class CreateEventWishWallSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :event_wish_wall_settings do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.string :display_mode, null: false, default: 'cards'
      t.string :animation_shape
      t.string :animation_text
      t.string :accent_color
      t.string :header_text_color
      t.string :card_background_color

      t.timestamps
    end
  end
end
