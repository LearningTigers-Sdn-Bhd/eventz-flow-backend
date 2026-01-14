class V1::UploadsController < ApplicationController
  # POST /v1/uploads
  def create
    if params[:file].blank?
      return error_response(message: 'No file provided', status: :unprocessable_entity)
    end

    begin
      # Create and upload the blob using Active Storage
      # We store the 'target' in metadata for future organization/filtering
      blob = ActiveStorage::Blob.create_and_upload!(
        io: params[:file],
        filename: params[:file].original_filename,
        content_type: params[:file].content_type,
        metadata: { target: params[:target] || 'general' }
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
      error_response(message: "Upload failed: #{e.message}", status: :internal_server_error)
    end
  end
end
