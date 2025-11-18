module V1
  class VendorProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_vendor_and_authorize, only: [:show, :update]
    before_action :set_vendor_profile, only: [:show, :update]

    # GET /v1/vendor_profile (vendor's own)
    # GET /v1/vendors/:vendor_id/profile (organizer/org_owner)
    def show
      render json: format_vendor_profile(@vendor_profile), status: :ok
    end

    # PATCH /v1/vendor_profile (vendor's own)
    # PATCH /v1/vendors/:vendor_id/profile (organizer/org_owner)
    def update
      if @vendor_profile.update(vendor_profile_params)
        render json: format_vendor_profile(@vendor_profile), status: :ok
      else
        render json: { error: 'Validation Error', errors: @vendor_profile.errors.full_messages },
               status: :unprocessable_content
      end
    end

    private

    def set_vendor_and_authorize
      # If id param exists, it's an admin accessing another vendor's profile via /vendors/:id/profile
      if params[:id].present?
        @vendor = User.find(params[:id])
        unless @vendor.vendor?
          render json: { error: 'Not Found', message: 'User is not a vendor.' }, status: :not_found and return
        end
        
        # Check if user is org_owner or the organizer who created this vendor
        is_org_owner = current_user.is_org_owner?
        is_creator = @vendor.created_by_id == current_user.id && current_user.is_organizer?
        
        unless is_org_owner || is_creator
          render json: { error: 'Forbidden', message: 'Only org owners or the organizer who created this vendor can manage their profile.' },
                 status: :forbidden and return
        end
      else
        # No vendor_id param, vendor accessing their own profile
        unless current_user.vendor?
          render json: { error: 'Forbidden', message: 'Only vendors can manage their profile.' },
                 status: :forbidden and return
        end
        @vendor = current_user
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Vendor not found.' }, status: :not_found
    end

    def set_vendor_profile
      @vendor_profile = @vendor.vendor_profile || @vendor.build_vendor_profile
    end

    def vendor_profile_params
      params.require(:vendor_profile).permit(
        :image_path,
        :description,
        :category,
        :person_in_charge,
        :address,
        :notes
      )
    end

    def format_vendor_profile(profile)
      profile.as_json(
        only: [:id, :vendor_id, :image_path, :description, :category, :person_in_charge, :address, :notes, :created_at, :updated_at],
        methods: [],
        include: {
          vendor: { only: [:id, :full_name, :email, :phone, :created_by_id] }
        }
      )
    end
  end
end
