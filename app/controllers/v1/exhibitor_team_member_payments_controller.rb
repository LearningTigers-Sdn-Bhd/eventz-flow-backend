module V1
  class ExhibitorTeamMemberPaymentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_exhibitor_kit
    before_action :set_exhibitor_team_member_payment, only: %i[show update]

    def index
      @exhibitor_team_member_payments = policy_scope(@exhibitor_kit.exhibitor_team_member_payments)

      render json: @exhibitor_team_member_payments.map { |payment| format_payment(payment) }, status: :ok
    end

    def show
      authorize @exhibitor_team_member_payment
      render json: format_payment(@exhibitor_team_member_payment), status: :ok
    end

    def create
      @exhibitor_team_member_payment = @exhibitor_kit.exhibitor_team_member_payments.new(create_params)
      authorize @exhibitor_team_member_payment

      # Validate exhibitor kit has unpaid excess team members
      unless @exhibitor_kit.has_unpaid_excess_team_members?
        return render json: { error: 'No unpaid excess team members to pay for' }, status: :unprocessable_content
      end

      # Set calculated values from exhibitor kit (only unpaid excess)
      @exhibitor_team_member_payment.extra_member_count = @exhibitor_kit.unpaid_excess_team_member_count
      @exhibitor_team_member_payment.fee_per_member = @exhibitor_kit.extra_team_member_fee
      @exhibitor_team_member_payment.amount = @exhibitor_kit.extra_team_member_charges
      @exhibitor_team_member_payment.status = :submitted

      if @exhibitor_team_member_payment.save
        render json: format_payment(@exhibitor_team_member_payment), status: :created
      else
        render json: { error: 'Validation failed', errors: @exhibitor_team_member_payment.errors.full_messages },
               status: :unprocessable_content
      end
    end

    def update
      authorize @exhibitor_team_member_payment

      update_params = exhibitor_team_member_payment_params

      # Auto-set status to 'submitted' when vendor provides payment proof
      if is_vendor? && (update_params[:payment_proof].present? || update_params[:external_ref].present?)
        update_params = update_params.merge(status: 'submitted')
      end

      # Record the payee (organizer) when status is changed to 'verified'
      if update_params[:status] == 'verified' && @exhibitor_team_member_payment.payee_id.nil?
        update_params = update_params.merge(payee_id: current_user.id)
      end

      if @exhibitor_team_member_payment.update(update_params)
        render json: format_payment(@exhibitor_team_member_payment), status: :ok
      else
        render json: { error: 'Validation failed', errors: @exhibitor_team_member_payment.errors.full_messages },
               status: :unprocessable_content
      end
    end

    private

    def format_payment(payment)
      payment.as_json(
        include: [:payee]
      ).merge(
        payment_proof_url: payment.payment_proof.attached? ? url_for(payment.payment_proof) : nil,
        exhibitor_kit_id: payment.exhibitor_kit_id,
        event_id: payment.exhibitor_kit.event_vendor.event_id
      )
    end

    def is_vendor?
      @exhibitor_kit.event_vendor.vendor_id == current_user.id
    end

    def set_exhibitor_kit
      @exhibitor_kit = ExhibitorKit.find(params[:exhibitor_kit_id])
    end

    def set_exhibitor_team_member_payment
      @exhibitor_team_member_payment = @exhibitor_kit.exhibitor_team_member_payments.find(params[:id])
    end

    def exhibitor_team_member_payment_params
      permitted = policy(@exhibitor_team_member_payment).permitted_attributes_for_update
      params.require(:exhibitor_team_member_payment).permit(*permitted)
    end

    def create_params
      params.require(:exhibitor_team_member_payment).permit(:payment_proof, :payment_source, :external_ref, :note)
    end
  end
end
