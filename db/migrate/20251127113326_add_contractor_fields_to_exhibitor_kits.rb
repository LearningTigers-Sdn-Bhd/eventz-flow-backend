class AddContractorFieldsToExhibitorKits < ActiveRecord::Migration[8.0]
  def change
    add_column :exhibitor_kits, :payment_status, :integer, default: 0
    add_column :exhibitor_kits, :amount_paid, :decimal, precision: 10, scale: 2
    add_column :exhibitor_kits, :payment_note, :text
    add_column :exhibitor_kits, :indemnity_link, :string
  end
end
