class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :full_name
      t.string :phone
      t.integer :role

      t.timestamps
    end
    add_index :users, :email
  end
end
