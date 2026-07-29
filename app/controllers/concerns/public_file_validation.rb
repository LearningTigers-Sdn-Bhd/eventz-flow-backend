# frozen_string_literal: true

# Shared file validation for public (unauthenticated) upload endpoints.
# One allowlist for registration documents and payment proofs.
module PublicFileValidation
  extend ActiveSupport::Concern

  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp application/pdf].freeze

  private

  def allowed_file_type?(file, allowed: ALLOWED_CONTENT_TYPES)
    allowed.include?(file.content_type)
  end

  def file_too_large?(file, max_bytes)
    file.size.to_i > max_bytes
  end
end
