class V1::UploadsController < ApplicationController
  # Maximum file size by target (optimized for different use cases)
  MAX_FILE_SIZE = {
    'rich-editor' => 10.megabytes,  # Rich text editor images - smaller, optimized
    'resources' => 10.megabytes,    # Resource header images
    'general' => 50.megabytes       # General uploads (PDFs, Excel, etc.)
  }.freeze

  # Default max file size
  DEFAULT_MAX_FILE_SIZE = 50.megabytes

  # Maximum image dimensions for rich text editor (prevents huge images)
  RICH_EDITOR_MAX_DIMENSIONS = {
    width: 2400,
    height: 2400
  }.freeze

  # Allowed content types by target
  ALLOWED_CONTENT_TYPES = {
    'rich-editor' => ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'],
    'resources' => ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'],
    'general' => ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'application/pdf', 'text/csv', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
  }.freeze

  # POST /v1/uploads
  def create
    if params[:file].blank?
      return error_response(message: 'No file provided', status: :unprocessable_entity)
    end

    target = params[:target] || 'general'

    # Validate file size based on target
    max_size = MAX_FILE_SIZE[target] || DEFAULT_MAX_FILE_SIZE
    if params[:file].size > max_size
      return error_response(
        message: "File size exceeds maximum allowed size of #{max_size / 1.megabyte}MB",
        status: :unprocessable_entity
      )
    end

    # Validate content type based on target
    allowed_types = ALLOWED_CONTENT_TYPES[target] || ALLOWED_CONTENT_TYPES['general']
    unless allowed_types.include?(params[:file].content_type)
      return error_response(
        message: "File type '#{params[:file].content_type}' is not allowed. Allowed types: #{allowed_types.join(', ')}",
        status: :unprocessable_entity
      )
    end

    begin
      file_io = params[:file]
      original_filename = params[:file].original_filename
      content_type = params[:file].content_type

      # Optimize images for rich text editor (compress and resize)
      if target == 'rich-editor' && image_type?(content_type)
        file_io, original_filename, content_type = optimize_image_for_rich_editor(file_io, original_filename, content_type)
      end

      # Create and upload the blob using Active Storage
      # We store the 'target' in metadata for future organization/filtering
      blob = ActiveStorage::Blob.create_and_upload!(
        io: file_io,
        filename: original_filename,
        content_type: content_type,
        metadata: {
          target: target,
          uploaded_by: current_user&.id,
          uploaded_at: Time.current.iso8601
        }
      )

      # Return the permanent URL (proxied through Rails)
      success_response(data: {
        url: url_for(blob),
        signed_id: blob.signed_id,
        filename: blob.filename.to_s,
        content_type: blob.content_type,
        byte_size: blob.byte_size
      })
    rescue => e
      Rails.logger.error "Upload failed: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      error_response(message: "Upload failed: #{e.message}", status: :internal_server_error)
    end
  end

  private

  # Check if content type is an image
  def image_type?(content_type)
    content_type.to_s.start_with?('image/')
  end

  # Optimize image for rich text editor use
  # - Resizes if too large
  # - Converts to WebP if vips is available
  # - Compresses for smaller file size
  def optimize_image_for_rich_editor(file_io, filename, content_type)
    # Check if vips is available
    unless vips_available?
      Rails.logger.debug "Vips not available, skipping image optimization for rich editor"
      return [file_io, filename, content_type]
    end

    begin
      require 'vips'

      # Read file content into memory for vips processing
      file_content = file_io.read

      # Open image with vips from buffer
      image = Vips::Image.new_from_buffer(file_content, '')

      # Get original dimensions
      original_width = image.width
      original_height = image.height

      # Resize if larger than max dimensions (maintain aspect ratio)
      if original_width > RICH_EDITOR_MAX_DIMENSIONS[:width] || original_height > RICH_EDITOR_MAX_DIMENSIONS[:height]
        scale = [
          RICH_EDITOR_MAX_DIMENSIONS[:width].to_f / original_width,
          RICH_EDITOR_MAX_DIMENSIONS[:height].to_f / original_height
        ].min

        image = image.resize(scale)
        Rails.logger.debug "Resized image from #{original_width}x#{original_height} to #{image.width}x#{image.height}"
      end

      # Convert to WebP for better compression (85% quality - good balance)
      # strip: true removes metadata for smaller file size
      webp_data = image.write_to_buffer('.webp', Q: 85, strip: true)

      # Update return values
      new_filename = File.basename(filename, File.extname(filename)) + '.webp'
      new_content_type = 'image/webp'

      # Create a new StringIO object from the WebP data for Active Storage
      optimized_io = StringIO.new(webp_data)

      # Log optimization results
      original_size = file_content.bytesize
      optimized_size = webp_data.bytesize
      savings = ((original_size - optimized_size).to_f / original_size * 100).round(2)

      Rails.logger.info "Rich editor image optimized: #{original_size / 1024.0}KB -> #{optimized_size / 1024.0}KB (#{savings}% reduction)"

      [optimized_io, new_filename, new_content_type]
    rescue LoadError => e
      Rails.logger.warn "Vips library not available for image optimization: #{e.message}"
      [file_io, filename, content_type]
    rescue => e
      Rails.logger.error "Image optimization failed: #{e.class} - #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      # Fall back to original file if optimization fails
      [file_io, filename, content_type]
    end
  end

  # Check if vips is available
  def vips_available?
    @vips_available ||= begin
      require 'vips'
      # Test that vips actually works
      Vips::Image.black(1, 1)
      true
    rescue LoadError, NoMethodError
      false
    end
  end
end
