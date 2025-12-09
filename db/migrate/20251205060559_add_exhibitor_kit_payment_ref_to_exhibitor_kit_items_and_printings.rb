class AddExhibitorKitPaymentRefToExhibitorKitItemsAndPrintings < ActiveRecord::Migration[8.0]
  def change
    add_reference :exhibitor_kit_items, :exhibitor_kit_payment, null: true, foreign_key: true
    add_reference :exhibitor_kit_printings, :exhibitor_kit_payment, null: true, foreign_key: true
  end
end
