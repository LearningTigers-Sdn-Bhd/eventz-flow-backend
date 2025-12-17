module V1
  class VendorsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_vendor, only: [:show, :update, :toggle_status, :destroy]

    # GET /v1/vendors
    def index
      authorize User.new(role: :vendor), :index?, policy_class: VendorPolicy
      
      vendors = policy_scope(User).where(role: :vendor)

      render json: vendors.map { |vendor| format_vendor(vendor) }, status: :ok
    end

    # GET /v1/vendors/:id
    def show
      authorize @vendor, :show?, policy_class: VendorPolicy
      
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
        email_verified_at: Time.current,
        created_by_id: current_user.id
      )

      authorize vendor_user, :create?, policy_class: VendorPolicy

      if vendor_user.save
        # Update vendor profile if attributes provided
        if params[:vendor][:vendor_profile_attributes].present? && vendor_user.vendor_profile
          profile_params = params.require(:vendor).permit(vendor_profile_attributes: [
            :description, :category, :person_in_charge, :address, :notes
          ])[:vendor_profile_attributes]
          vendor_user.vendor_profile.update(profile_params)

          # Handle image upload via Active Storage
          handle_profile_image_attachment(vendor_user.vendor_profile)
        end

        render json: format_vendor(vendor_user), status: :created
      else
        render json: { error: 'Validation Error', errors: vendor_user.errors.full_messages },
               status: :unprocessable_content
      end
    end

    # PUT/PATCH /v1/vendors/:id
    def update
      authorize @vendor, :update?, policy_class: VendorPolicy

      if @vendor.update(vendor_update_params)
        # Handle vendor profile image via Active Storage AFTER update
        # This ensures the profile exists and is saved before attaching
        if params[:vendor][:vendor_profile_attributes].present?
          handle_profile_image_attachment(@vendor.vendor_profile)
        end

        render json: format_vendor(@vendor.reload), status: :ok
      else
        render json: { error: 'Validation failed', errors: @vendor.errors.full_messages },
               status: :unprocessable_content
      end
    end

    # PATCH /v1/vendors/:id/toggle_status
    def toggle_status
      authorize @vendor, :toggle_status?, policy_class: VendorPolicy
      
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

    # DELETE /v1/vendors/:id
    def destroy
      authorize @vendor, :destroy?, policy_class: VendorPolicy
      
      return render_cannot_delete_self if deleting_self?

      @vendor.destroy
      render json: format_vendor(@vendor), status: :ok
    end

    private

    # Handle image upload and removal via Active Storage for vendor profile
    def handle_profile_image_attachment(profile)
      return unless profile

      # New image upload
      uploaded_image = params.dig(:vendor, :vendor_profile_attributes, :image)
      if uploaded_image.present? && uploaded_image.respond_to?(:read)
        profile.image.attach(uploaded_image)
        return
      end

      # Image removal (accepts boolean true, string "true", or "1")
      remove_flag = params.dig(:vendor, :vendor_profile_attributes, :remove_image)
      if ActiveModel::Type::Boolean.new.cast(remove_flag)
        profile.image.purge_later if profile.image.attached?
      end
    end

    def set_vendor
      @vendor = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Vendor not found' }, status: :not_found
    end

    def vendor_update_params
      # Build the list of permitted params dynamically
      permitted_params = [:full_name, :email, :phone]

      # Include password fields if password is provided
      if params[:vendor][:password].present?
        permitted_params.push(:password, :password_confirmation)
      end

      # Include vendor_profile attributes if provided
      # Note: :image and :remove_image are handled separately via Active Storage
      if params[:vendor][:vendor_profile_attributes].present?
        permitted_params << {
          vendor_profile_attributes: [
            :id,
            :description,
            :category,
            :person_in_charge,
            :address,
            :notes
          ]
        }
      end

      params.require(:vendor).permit(permitted_params)
    end

    def format_vendor(vendor)
      vendor_profile = vendor.vendor_profile

      {
        id: vendor.id,
        email: vendor.email,
        full_name: vendor.full_name,
        phone: vendor.phone,
        role: vendor.role,
        status: vendor.status,
        created_at: vendor.created_at.iso8601,
        updated_at: vendor.updated_at.iso8601,
        vendor_profile: vendor_profile ? format_vendor_profile(vendor_profile) : nil
      }
    end

    def format_vendor_profile(vendor_profile)
      {
        id: vendor_profile.id,
        vendor_id: vendor_profile.vendor_id,
        image_url: vendor_profile.image.attached? ? url_for(vendor_profile.image) : nil,
        description: vendor_profile.description,
        category: vendor_profile.category,
        person_in_charge: vendor_profile.person_in_charge,
        address: vendor_profile.address,
        notes: vendor_profile.notes,
        created_at: vendor_profile.created_at.iso8601,
        updated_at: vendor_profile.updated_at.iso8601
      }
    end

    def deleting_self?
      @vendor.id == current_user.id
    end

    def render_cannot_delete_self
      render json: { error: 'You cannot delete your own account' }, status: :unprocessable_content
    end
  end
end
