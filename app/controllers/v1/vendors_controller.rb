module V1
  class VendorsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_manager!
    before_action :set_vendor, only: [:show, :update, :toggle_status]

    # GET /v1/vendors
    def index
      vendors = User.where(role: :vendor)

      render json: vendors.map { |vendor| format_vendor(vendor) }, status: :ok
    end

    # GET /v1/vendors/:id
    def show
      render json: format_vendor(@vendor), status: :ok
    end

    # POST /v1/vendors
    def create
      vendor_params_required = params.require(:vendor).permit(:full_name, :email, :phone, :password, :password_confirmation)

      # Create vendor user
      vendor_user = User.new(
        full_name: vendor_params_required[:full_name],
        email: vendor_params_required[:email],
        phone: vendor_params_required[:phone],
        password: vendor_params_required[:password],
        password_confirmation: vendor_params_required[:password_confirmation],
        role: :vendor,
        status: :active,
        email_verified_at: Time.current
      )

      if vendor_user.save
        render json: format_vendor(vendor_user), status: :created
      else
        render json: { error: 'Validation Error', errors: vendor_user.errors.full_messages },
               status: :unprocessable_content
      end
    end

    # PUT/PATCH /v1/vendors/:id
    def update
      if @vendor.update(vendor_update_params)
        render json: format_vendor(@vendor), status: :ok
      else
        render json: { error: 'Validation failed', errors: @vendor.errors.full_messages },
               status: :unprocessable_content
      end
    end

    # PATCH /v1/vendors/:id/toggle_status
    def toggle_status
      unless params[:status].in?(['active', 'inactive'])
        return render json: { error: 'Invalid status value' }, status: :unprocessable_content
      end

      if @vendor.update(status: params[:status])
        render json: format_vendor(@vendor), status: :ok
      else
        render json: { error: 'Validation failed', errors: @vendor.errors.full_messages },
               status: :unprocessable_content
      end
    end

    private

    def set_vendor
      @vendor = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Vendor not found' }, status: :not_found
    end

    def vendor_update_params
      permitted = params.require(:vendor).permit(
        :full_name,
        :email,
        :phone
      )

      # Only include password fields if password is provided
      if params[:vendor][:password].present?
        permitted.merge!(
          params.require(:vendor).permit(:password, :password_confirmation)
        )
      end

      permitted
    end

    def format_vendor(vendor)
      {
        id: vendor.id,
        email: vendor.email,
        full_name: vendor.full_name,
        phone: vendor.phone,
        role: vendor.role,
        status: vendor.status,
        created_at: vendor.created_at.iso8601,
        updated_at: vendor.updated_at.iso8601
      }
    end

    def authorize_manager!
      unless current_user.is_manager?
        render json: { error: 'Forbidden', message: 'Only managers can manage vendors.' },
               status: :forbidden
      end
    end
  end
end
