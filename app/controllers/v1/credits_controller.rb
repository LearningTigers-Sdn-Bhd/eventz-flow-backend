module V1
  class CreditsController < ApplicationController
    # GET /v1/credits/stats
    def stats
      user = find_owner
      render json: { current_balance: user.credit_balance }
    end

    # GET /v1/credits/transaction_logs
    def transaction_logs
      user = find_owner
      wallet = user.credit_wallet
      transactions = wallet ? wallet.credit_transactions.order(created_at: :desc) : []
      
      render json: transactions.map { |t| {
        id: t.id,
        date: t.created_at.iso8601,
        description: t.description,
        type: t.transaction_type,
        amount: t.amount,
        balance: t.balance_after
      }}
    end

    # GET /v1/credits/deductions
    def deductions
      user = find_owner
      deductions = CreditDeduction.where(owner: user).order(created_at: :desc)
      
      render json: deductions.map { |d| {
        id: d.id,
        event: d.event&.title || "General",
        recipient: d.recipient,
        channel: d.channel,
        credits: d.credits,
        status: d.status,
        date: d.created_at.iso8601
      }}
    end

    # GET /v1/credits/consumption_charges
    def consumption_charges
      # Placeholder for static pricing info
      render json: [
        { id: "1", country: "Global", countryCode: "*", waMessageCredits: 1 },
        { id: "2", country: "TTS", countryCode: "elevenlabs", waMessageCredits: 1 } # 1 per 100 chars
      ]
    end

    private

    def find_owner
      if current_user.org_owner? && params[:user_id]
        User.find(params[:user_id])
      else
        current_user
      end
    end
  end
end
