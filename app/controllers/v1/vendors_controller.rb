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
          handle_vendor_profile_image_upload(nil)
          profile_params = params.require(:vendor).permit(vendor_profile_attributes: [
            :image_path, :description, :category, :person_in_charge, :address, :notes
          ])[:vendor_profile_attributes]
          vendor_user.vendor_profile.update(profile_params)
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
      
      # Handle vendor profile image if present
      if params[:vendor][:vendor_profile_attributes].present?
        handle_vendor_profile_image_upload(@vendor)
      end

      if @vendor.update(vendor_update_params)
        render json: format_vendor(@vendor), status: :ok
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

    # Handle image upload for vendor profile nested attributes
    # @param vendor [User, nil] The vendor user (pass nil for create, vendor instance for update)
    def handle_vendor_profile_image_upload(vendor = nil)
      uploaded_image = params.dig(:vendor, :vendor_profile_attributes, :image)
      
      if uploaded_image.present? && uploaded_image.respond_to?(:read)
        image_path = store_vendor_image(uploaded_image, vendor)
        if image_path
          params[:vendor][:vendor_profile_attributes][:image_path] = image_path
          params[:vendor][:vendor_profile_attributes].delete(:image)
        end
      elsif vendor && params.dig(:vendor, :vendor_profile_attributes, :image_path) == ""
        # Explicitly handle empty string as removal request (only on update)
        params[:vendor][:vendor_profile_attributes][:image_path] = nil
      end
    end

    # Store uploaded vendor image to filesystem
    # @param uploaded_file [ActionDispatch::Http::UploadedFile] The uploaded image file
    # @param vendor [User, nil] The vendor user (pass nil for create to skip old image deletion)
    # @return [String, nil] The file path relative to storage root, or nil if storage failed
    def store_vendor_image(uploaded_file, vendor = nil)
      images_dir = Rails.root.join('storage', 'vendor_images')
      FileUtils.mkdir_p(images_dir)

      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      extension = File.extname(uploaded_file.original_filename)
      filename = "vendor-#{timestamp}-#{SecureRandom.hex(4)}#{extension}"
      file_path = images_dir.join(filename)

      # Delete old image only on update (when vendor exists)
      if vendor&.vendor_profile&.image_path.present?
        old_image_path = Rails.root.join('storage', vendor.vendor_profile.image_path)
        File.delete(old_image_path) if File.exist?(old_image_path)
      end

      File.open(file_path, 'wb') { |file| file.write(uploaded_file.read) }
      "vendor_images/#{filename}"
    rescue StandardError => e
      Rails.logger.error "Failed to store vendor image: #{e.message}"
      nil
    end

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

      # Include vendor_profile attributes if provided
      if params[:vendor][:vendor_profile_attributes].present?
        permitted.merge!(
          params.require(:vendor).permit(vendor_profile_attributes: [
            :image_path,
            :description,
            :category,
            :person_in_charge,
            :address,
            :notes
          ])
        )
      end

      permitted
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
        image_path: vendor_profile.image_path,
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
