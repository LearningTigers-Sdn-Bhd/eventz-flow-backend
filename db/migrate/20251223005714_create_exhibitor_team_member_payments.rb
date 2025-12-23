class CreateExhibitorTeamMemberPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_team_member_payments do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true
      t.references :payee, foreign_key: { to_table: :users }
      t.integer :extra_member_count, null: false
      t.decimal :fee_per_member, precision: 10, scale: 2, null: false
      t.decimal :amount, precision: 10, scale: 2, default: 0.0
      t.integer :status, default: 0
      t.string :payment_source
      t.string :external_ref
      t.text :note
      t.datetime :paid_at

      t.timestamps
    end
  end
end
