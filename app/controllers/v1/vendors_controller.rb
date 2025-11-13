module V1
  class VendorsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_manager!

    # GET /v1/vendors
    def index
      vendors = User.where(role: :vendor)

      render json: vendors.map { |vendor|
        {
          id: vendor.id,
          email: vendor.email,
          full_name: vendor.full_name,
          phone: vendor.phone,
          role: vendor.role,
          status: vendor.status,
          created_at: vendor.created_at,
          updated_at: vendor.updated_at
        }
      }, status: :ok
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
        render json: {
          id: vendor_user.id,
          email: vendor_user.email,
          full_name: vendor_user.full_name,
          phone: vendor_user.phone,
          role: vendor_user.role,
          status: vendor_user.status
        }, status: :created
      else
        render json: { error: 'Validation Error', errors: vendor_user.errors.full_messages },
               status: :unprocessable_content
      end
    end

    private

    def authorize_manager!
      unless current_user.is_manager?
        render json: { error: 'Forbidden', message: 'Only managers can create vendors.' },
               status: :forbidden
      end
    end
  end
end
