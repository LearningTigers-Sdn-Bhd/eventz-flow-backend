class AddPassBundleToTickets < ActiveRecord::Migration[8.0]
  def change
    add_reference :tickets, :pass_bundle, foreign_key: true
  end
end
