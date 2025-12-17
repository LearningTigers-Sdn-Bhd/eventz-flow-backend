module V1
  class VendorProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_vendor, only: [:show, :update]
    before_action :set_vendor_profile, only: [:show, :update]

    # GET /v1/vendor_profile (vendor's own)
    # GET /v1/vendors/:vendor_id/profile (organizer/org_owner)
    def show
      authorize @vendor_profile
      render json: format_vendor_profile(@vendor_profile), status: :ok
    end

    # PATCH /v1/vendor_profile (vendor's own)
    # PATCH /v1/vendors/:vendor_id/profile (organizer/org_owner)
    def update
      authorize @vendor_profile

      handle_image_attachment

      if @vendor_profile.update(vendor_profile_params)
        render json: format_vendor_profile(@vendor_profile), status: :ok
      else
        render json: { error: 'Validation Error', errors: @vendor_profile.errors.full_messages },
              status: :unprocessable_content
      end
    end

    private

    def set_vendor
      if params[:id].present?
        @vendor = User.find(params[:id])
        unless @vendor.vendor?
          render json: { error: 'Not Found', message: 'User is not a vendor.' }, status: :not_found and return
        end
      else
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
        :description,
        :category,
        :person_in_charge,
        :address,
        :notes
      )
    end

    # Handle image upload and removal via Active Storage
    def handle_image_attachment
      # New image upload (supports both root-level and nested params)
      uploaded_image = params[:image] || params.dig(:vendor_profile, :image)
      if uploaded_image.present?
        @vendor_profile.image.attach(uploaded_image)
        return
      end

      # Image removal (accepts boolean true, string "true", or "1")
      # Uses purge_later for non-blocking deletion via background job
      remove_flag = params[:remove_image] || params.dig(:vendor_profile, :remove_image)
      if ActiveModel::Type::Boolean.new.cast(remove_flag)
        @vendor_profile.image.purge_later if @vendor_profile.image.attached?
      end
    end

    def format_vendor_profile(profile)
      profile.as_json(
        only: [:id, :vendor_id, :description, :category, :person_in_charge, :address, :notes, :created_at, :updated_at],
        methods: [],
        include: {
          vendor: { only: [:id, :full_name, :email, :phone, :created_by_id] }
        }
      ).merge(image_url: profile.image.attached? ? url_for(profile.image) : nil)
    end
  end
end
