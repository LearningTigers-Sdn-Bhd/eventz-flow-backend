class AddPublicRegistrationUrlToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :public_registration_url, :string
  end
end
