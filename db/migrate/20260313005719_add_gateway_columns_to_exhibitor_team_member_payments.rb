class AddGatewayColumnsToExhibitorTeamMemberPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :exhibitor_team_member_payments, :gateway, :string
    add_column :exhibitor_team_member_payments, :gateway_payment_id, :string
    add_column :exhibitor_team_member_payments, :payment_method, :string
    add_column :exhibitor_team_member_payments, :gateway_response, :jsonb, default: {}, null: false

    add_index :exhibitor_team_member_payments, :gateway_payment_id
  end
end
