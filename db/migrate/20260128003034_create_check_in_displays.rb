class CreateCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    create_table :check_in_displays do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.string :font_family, default: 'Inter'
      t.integer :font_size, default: 72
      t.integer :animation_type, default: 0
      t.boolean :is_bold, default: false
      t.string :name_color, default: '#FFFFFF'

      t.timestamps
    end
  end
end
