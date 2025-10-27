class AddJtiToUsers < ActiveRecord::Migration[8.0]
  def change
    # Add column as nullable first
    add_column :users, :jti, :string

    # Generate jti for existing users
    User.reset_column_information
    User.find_each do |user|
      user.update_column(:jti, SecureRandom.uuid)
    end

    # Now add unique index and make non-nullable
    add_index :users, :jti, unique: true
    change_column_null :users, :jti, false
  end
end
