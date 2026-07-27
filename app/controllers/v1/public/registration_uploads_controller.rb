# frozen_string_literal: true

module V1
  module Public
    class RegistrationUploadsController < ApplicationController
      include PublicFileValidation

      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      MAX_FILE_SIZE = 10.megabytes
      MAX_SIGNATURE_SIZE = 2.megabytes

      def create
        event = Event.friendly.find(params[:event_slug])

        unless event.published?
          return render json: { success: false, message: 'Registration is not open for this event' },
                        status: :unprocessable_content
        end

        key = params[:key].to_s
        unless Ticket::DOCUMENT_KEYS.include?(key)
          return render json: { success: false, message: 'Unsupported document type' },
                        status: :unprocessable_content
        end

        file = params[:file]
        if file.blank? || !file.respond_to?(:content_type)
          return render json: { success: false, message: 'File is required' }, status: :unprocessable_content
        end

        unless allowed_file_type?(file)
          return render json: { success: false, message: 'File must be a JPEG, PNG, WebP, or PDF' },
                        status: :unprocessable_content
        end

        max_size = key == 'signature' ? MAX_SIGNATURE_SIZE : MAX_FILE_SIZE
        if file_too_large?(file, max_size)
          return render json: { success: false, message: "File is too large (max #{max_size / 1.megabyte}MB)" },
                        status: :unprocessable_content
        end

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: file.original_filename,
          content_type: file.content_type,
          metadata: {
            document_key: key,
            event_id: event.id,
            uploaded_at: Time.current.iso8601
          }
        )

        render json: {
          success: true,
          data: {
            key: key,
            signed_id: blob.signed_id,
            filename: blob.filename.to_s,
            content_type: blob.content_type,
            byte_size: blob.byte_size
          }
        }, status: :created
      end
    end
  end
end
