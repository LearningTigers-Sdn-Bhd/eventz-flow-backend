class CreateCreditSystem < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_wallets do |t|
      t.references :group, null: false, foreign_key: true, index: { unique: true }
      t.integer :balance, default: 0, null: false
      t.timestamps
    end

    create_table :credit_transactions do |t|
      t.references :credit_wallet, null: false, foreign_key: true
      t.integer :transaction_type, null: false # enum: purchase, refund, bonus, deduction
      t.integer :amount, null: false
      t.integer :balance_after, null: false
      t.string :description
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    create_table :credit_deductions do |t|
      t.references :group, null: false, foreign_key: true
      t.references :event, foreign_key: true
      t.string :channel, null: false # whatsapp, tts, etc.
      t.integer :credits, null: false
      t.string :recipient
      t.integer :status, default: 0, null: false # enum: pending, sent, failed
      t.timestamps
    end
  end
end

