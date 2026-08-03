class AddNoteToExhibitorRegistrationPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :exhibitor_registration_payments, :note, :text
  end
end
