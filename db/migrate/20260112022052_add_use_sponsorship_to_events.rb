class AddUseSponsorshipToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_sponsorship, :boolean, default: false
  end
end