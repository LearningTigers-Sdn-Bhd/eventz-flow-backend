module V1
  class VouchersController < ApplicationController
    # NOTE: The helper methods (policy_scope, authorize, current_user) below are
    # required for this file to be runnable in the immersive environment.
    # In a real Rails app, they would be provided by Pundit/Authenticable and could be removed.

    before_action :set_voucher, only: [:show, :update, :destroy]
    # Authorizes the loaded @voucher for the three standard resource actions (show?, update?, destroy?).
    before_action :authorize_resource, only: [:show, :update, :destroy]

    skip_before_action :authenticate_user!, only: [:serve_image]
    skip_before_action :require_verified_email!, only: [:serve_image]

    # GET /api/v1/vouchers
    def index
      # 1. Scope the results using the VoucherPolicy::Scope
      @vouchers = policy_scope(Voucher)

      # 2. Apply filters if provided in query parameters (only to the authorized set)
      if params[:event_id].present? # Check for event_id from nested route (friendly ID)
        event = Event.friendly.find(params[:event_id])
        @vouchers = @vouchers.where(event_id: event.id)
      elsif filter_params.key?(:vendor_id)
        @vouchers = @vouchers.where(vendor_id: filter_params[:vendor_id])
      elsif filter_params.key?(:event_id) # Fallback for event_id as a query parameter (original behavior)
        @vouchers = @vouchers.where(event_id: filter_params[:event_id])
      end

      # Include vendor association and convert to array
      success_response(data: @vouchers.includes(:vendor).as_json(include: { vendor: { only: [:id, :full_name, :email, :phone] } }))
    end

    # GET /api/v1/vouchers/:id
    def show
      # Authorization handled by before_action :authorize_resource
      success_response(data: @voucher.as_json(include: { vendor: { only: [:id, :full_name, :email, :phone] } }))
    end

    # POST /api/v1/vouchers
    def create
      @voucher = Voucher.new(voucher_params)
      # Authorization must be called explicitly before attempting to save
      authorize @voucher

      # Process image upload if provided (multipart form data sends it at root level)
      if params[:image].present?
        image_path = store_voucher_image(params[:image])
        @voucher.image_path = image_path if image_path
      end

      if @voucher.save
        success_response(data: @voucher.as_json(include: { vendor: { only: [:id, :full_name, :email, :phone] } }), status: :created, message: 'Voucher created successfully')
      else
        # Rely on ApplicationController's error_response format
        error_response(
          message: 'Validation failed',
          errors: @voucher.errors.full_messages,
          status: :unprocessable_content
        )
      end
      # Pundit::NotAuthorizedError rescue block removed, handled globally
    end

    # GET /voucher_images/:filename [activestorage-implementation-change]
    def serve_image
      filename = params[:filename]
      # Security check to prevent directory traversal
      if filename.include?('..') || filename.include?('/') || filename.include?('\\')
        return head :bad_request
      end

      path = Rails.root.join('storage', 'voucher_images', filename)

      if File.exist?(path)
        send_file path, disposition: 'inline'
      else
        head :not_found
      end
    end

    # PATCH/PUT /api/v1/vouchers/:id
    def update
      # Authorization handled by before_action :authorize_resource

      # Handle image removal if requested
      if params[:remove_image] == 'true' || params[:remove_image] == true
        # Delete the old image file if it exists
        if @voucher.image_path.present?
          old_image_path = Rails.root.join('storage', @voucher.image_path)
          File.delete(old_image_path) if File.exist?(old_image_path)
        end
        @voucher.image_path = nil
      # Process image upload if provided (multipart form data sends it at root level)
      elsif params[:image].present?
        image_path = store_voucher_image(params[:image])
        @voucher.image_path = image_path if image_path
      end

      if @voucher.update(voucher_params)
        success_response(data: @voucher.as_json(include: { vendor: { only: [:id, :full_name, :email, :phone] } }), status: :ok, message: 'Voucher updated successfully')
      else
        error_response(
          message: 'Validation failed',
          errors: @voucher.errors.full_messages,
          status: :unprocessable_content
        )
      end
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

    # Strong parameters for creating and updating a voucher
    # Note: For multipart/form-data, params come at root level, not nested under :voucher
    def voucher_params
      params.permit(
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
        :is_unlimited,
        :max_redemptions_per_user,
        :voucher_type,
        :voucher_value,
        :voucher_category
      )
    end

    # Parameters used for filtering the index action via query parameters
    def filter_params
      params.permit(:vendor_id, :event_id)
    end

    # Store uploaded voucher image to filesystem
    # @param uploaded_file [ActionDispatch::Http::UploadedFile] The uploaded image file
    # @return [String, nil] The file path relative to storage root, or nil if storage failed
    def store_voucher_image(uploaded_file)
      # Create voucher_images directory if it doesn't exist
      images_dir = Rails.root.join('storage', 'voucher_images')
      FileUtils.mkdir_p(images_dir)

      # Generate filename with timestamp to ensure uniqueness
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      extension = File.extname(uploaded_file.original_filename)
      filename = "voucher-#{timestamp}-#{SecureRandom.hex(4)}#{extension}"
      file_path = images_dir.join(filename)

      # Write the uploaded file to disk
      File.open(file_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end

      # Return the relative path (from storage/)
      "voucher_images/#{filename}"
    rescue StandardError => e
      Rails.logger.error "Failed to store voucher image: #{e.message}"
      nil
    end
  end
end
