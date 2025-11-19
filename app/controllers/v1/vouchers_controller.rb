module V1
  class VouchersController < ApplicationController
    # NOTE: The helper methods (policy_scope, authorize, current_user) below are 
    # required for this file to be runnable in the immersive environment.
    # In a real Rails app, they would be provided by Pundit/Authenticable and could be removed.

    before_action :set_voucher, only: [:show, :update, :destroy]
    # Authorizes the loaded @voucher for the three standard resource actions (show?, update?, destroy?).
    before_action :authorize_resource, only: [:show, :update, :destroy]

    # GET /api/v1/vouchers
    def index
      # 1. Scope the results using the VoucherPolicy::Scope
      @vouchers = policy_scope(Voucher) 
      
      # 2. Apply filters if provided in query parameters (only to the authorized set)
      if filter_params.key?(:vendor_id)
        @vouchers = @vouchers.where(vendor_id: filter_params[:vendor_id])
      end

      if filter_params.key?(:event_id)
        @vouchers = @vouchers.where(event_id: filter_params[:event_id])
      end

      # Use the standard response helper
      success_response(data: @vouchers)
    end

    # GET /api/v1/vouchers/:id
    def show
      # Authorization handled by before_action :authorize_resource
      success_response(data: @voucher)
    end

    # POST /api/v1/vouchers
    def create
      @voucher = Voucher.new(voucher_params)
      # Authorization must be called explicitly before attempting to save
      authorize @voucher

      if @voucher.save
        success_response(data: @voucher, status: :created, message: 'Voucher created successfully')
      else
        # Rely on ApplicationController's error_response format
        error_response(
          message: 'Validation failed', 
          errors: @voucher.errors.full_messages, 
          status: :unprocessable_entity
        )
      end
      # Pundit::NotAuthorizedError rescue block removed, handled globally
    end

    # PATCH/PUT /api/v1/vouchers/:id
    def update
      # Authorization handled by before_action :authorize_resource
      if @voucher.update(voucher_params)
        success_response(data: @voucher, status: :ok, message: 'Voucher updated successfully')
      else
        # Rely on ApplicationController's error_response format
        error_response(
          message: 'Validation failed', 
          errors: @voucher.errors.full_messages, 
          status: :unprocessable_entity
        )
      end
      # Pundit::NotAuthorizedError rescue block removed, handled globally
    end

    # DELETE /api/v1/vouchers/:id
    def destroy
      # Authorization handled by before_action :authorize_resource
      @voucher.destroy
      success_response(status: :no_content, message: 'Voucher deleted successfully')
      # Pundit::NotAuthorizedError rescue block removed, handled globally
    end

    private
    
    # Authorizes the loaded @voucher resource. 
    def authorize_resource
      authorize @voucher
    end
    
    # Finds the voucher. ActiveRecord::RecordNotFound exception is now handled 
    # globally by ApplicationController#handle_not_found.
    def set_voucher
      @voucher = Voucher.find(params[:id])
    end
    
    # --- Pundit Helper Methods (Keep only if needed for local execution environment) ---
    
    def policy_scope(scope)
      Pundit::PolicyFinder.new(scope).policy.new(current_user, scope).resolve
    end
    
    def authorize(record, query = nil)
      query ||= "#{action_name}?"
      unless Pundit::PolicyFinder.new(record).policy.new(current_user, record).public_send(query)
        raise Pundit::NotAuthorizedError
      end
    end
    
    def current_user
      @current_user ||= User.find_by(id: params[:user_id])
      @current_user
    end
    
    # --- Existing methods ---

    # Strong parameters for creating and updating a voucher
    def voucher_params
      params.require(:voucher).permit(
        :vendor_id,
        :event_id,
        :title,
        :description,
        :voucher_code,
        :status,
        :start_date,
        :end_date,
        :start_time,
        :end_time,
        :total_redemption_available,
        :max_redemptions_per_user,
        :voucher_type,
        :voucher_value
      )
    end
    
    # Parameters used for filtering the index action via query parameters
    def filter_params
      params.permit(:vendor_id, :event_id)
    end
  end
end