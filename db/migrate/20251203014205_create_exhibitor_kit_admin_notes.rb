class CreateExhibitorKitAdminNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_kit_admin_notes do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :note

      t.timestamps
    end
  end
end
