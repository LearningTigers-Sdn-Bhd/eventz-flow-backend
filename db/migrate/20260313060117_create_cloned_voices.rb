class CreateClonedVoices < ActiveRecord::Migration[8.0]
  def change
    create_table :cloned_voices do |t|
      t.references :group, null: false, foreign_key: true
      t.references :event, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :elevenlabs_id
      t.string :name, null: false
      t.integer :status, default: 0, null: false # enum for pending, ready, failed
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :cloned_voices, :elevenlabs_id, unique: true
  end
end
