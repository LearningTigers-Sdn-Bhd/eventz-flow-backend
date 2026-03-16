class RenameGroupIdToOwnerIdInCreditAndVoice < ActiveRecord::Migration[8.0]
  def change
    # Cloned Voices
    remove_reference :cloned_voices, :group, foreign_key: true
    add_reference :cloned_voices, :owner, null: false, foreign_key: { to_table: :users }

    # Credit Wallets
    remove_reference :credit_wallets, :group, foreign_key: true
    add_reference :credit_wallets, :owner, null: false, foreign_key: { to_table: :users }, index: { unique: true }

    # Credit Deductions
    remove_reference :credit_deductions, :group, foreign_key: true
    add_reference :credit_deductions, :owner, null: false, foreign_key: { to_table: :users }
  end
end
