class DropRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :refresh_tokens, :users
    drop_table :refresh_tokens
  end
end
