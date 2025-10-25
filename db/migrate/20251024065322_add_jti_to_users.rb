class AddJtiToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :jti, :string
    add_index :users, :jti, unique: true

    # Backfill existing users with JTI
    reversible do |dir|
      dir.up do
        User.find_each do |user|
          user.update_column(:jti, SecureRandom.uuid)
        end
      end
    end
  end
end
