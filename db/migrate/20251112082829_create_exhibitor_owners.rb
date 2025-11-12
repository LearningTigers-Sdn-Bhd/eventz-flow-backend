class CreateExhibitorOwners < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_owners do |t|
      t.string :name, null: false
      t.text :description
      t.string :contact_email
      t.string :contact_phone

      t.timestamps
    end

    add_index :exhibitor_owners, :name
  end
end

