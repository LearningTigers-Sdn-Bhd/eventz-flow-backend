module V1
  class VendorProfilesController < ApplicationController
    before_action :authenticate_user!
    skip_before_action :authenticate_user!, only: [:serve_image]
    skip_before_action :require_verified_email!, only: [:serve_image] if defined?(require_verified_email!)

    before_action :set_vendor_and_authorize, only: [:show, :update]
    before_action :set_vendor_profile, only: [:show, :update]

    # GET /v1/vendor_profile (vendor's own)
    # GET /v1/vendors/:vendor_id/profile (organizer/org_owner)
    def show
      render json: format_vendor_profile(@vendor_profile), status: :ok
    end

    # GET /vendor_images/:filename
    def serve_image
      filename = params[:filename]
      # Security check to prevent directory traversal
      if filename.include?('..') || filename.include?('/') || filename.include?('\\')
        return head :bad_request
      end

      path = Rails.root.join('storage', 'vendor_images', filename)

      if File.exist?(path)
        send_file path, disposition: 'inline'
      else
        head :not_found
      end
    end

    # PATCH /v1/vendor_profile (vendor's own)
    # PATCH /v1/vendors/:vendor_id/profile (organizer/org_owner)
    def update
      attributes = vendor_profile_params.to_h

      # Handle explicit image removal (empty string means remove)
      if params.dig(:vendor_profile, :image_path) == ""
        # Delete old image file if exists
        if @vendor_profile.image_path.present?
          old_image_path = Rails.root.join('storage', @vendor_profile.image_path)
          File.delete(old_image_path) if File.exist?(old_image_path)
        end
        attributes[:image_path] = nil
      end

      # Process image upload if provided (support both root-level and nested params)
      uploaded_image = params[:image] || params.dig(:vendor_profile, :image)

      if uploaded_image.present? && uploaded_image.respond_to?(:read)
        image_path = store_vendor_image(uploaded_image)
        attributes[:image_path] = image_path if image_path
      end

      if @vendor_profile.update(attributes)
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

    # Store uploaded vendor image to filesystem
    # @param uploaded_file [ActionDispatch::Http::UploadedFile] The uploaded image file
    # @return [String, nil] The file path relative to storage root, or nil if storage failed
    def store_vendor_image(uploaded_file)
      # Create vendor_images directory if it doesn't exist
      images_dir = Rails.root.join('storage', 'vendor_images')
      FileUtils.mkdir_p(images_dir)

      # Generate filename with timestamp to ensure uniqueness
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      extension = File.extname(uploaded_file.original_filename)
      filename = "vendor-#{timestamp}-#{SecureRandom.hex(4)}#{extension}"
      file_path = images_dir.join(filename)

      # Delete old image if exists
      if @vendor_profile.image_path.present?
        old_image_path = Rails.root.join('storage', @vendor_profile.image_path)
        File.delete(old_image_path) if File.exist?(old_image_path)
      end

      # Write the uploaded file to disk
      File.open(file_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end

      # Return the relative path (from storage/)
      "vendor_images/#{filename}"
    rescue StandardError => e
      Rails.logger.error "Failed to store vendor image: #{e.message}"
      nil
    end
  end
end
