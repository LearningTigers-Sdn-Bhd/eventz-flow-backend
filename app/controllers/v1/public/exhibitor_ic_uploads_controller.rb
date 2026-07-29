# frozen_string_literal: true

module V1
  module Public
    class ExhibitorIcUploadsController < ApplicationController
      ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp application/pdf].freeze
      MAX_FILE_SIZE = 10.megabytes

      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create
        event = Event.friendly.find(params[:event_slug])
        unless event.published? && event.use_exhibitor_kit?
          return render json: { success: false, message: 'Registration is not open for this event' },
                        status: :unprocessable_content
        end

        file = params[:file]
        if file.blank? || !file.respond_to?(:content_type)
          return render json: { success: false, message: 'IC copy is required' }, status: :unprocessable_content
        end
        unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
          return render json: { success: false, message: 'IC copy must be a JPEG, PNG, WebP, or PDF' },
                        status: :unprocessable_content
        end
        if file.size.to_i > MAX_FILE_SIZE
          return render json: { success: false, message: 'IC copy is too large (max 10MB)' },
                        status: :unprocessable_content
        end

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: file.original_filename,
          content_type: file.content_type,
          metadata: { document_key: 'exhibitor_ic_copy', event_id: event.id, uploaded_at: Time.current.iso8601 }
        )

        render json: {
          success: true,
          data: { signed_id: blob.signed_id(expires_in: 1.hour), filename: blob.filename.to_s }
        }, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event not found' }, status: :not_found
      end
    end
  end
end
