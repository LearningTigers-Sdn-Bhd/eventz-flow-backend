require Rails.root.join('app/lib/custom_error')
require Rails.root.join('app/services/jwt_service')
require Rails.root.join('app/services/authentication_service')

class ApplicationController < ActionController::API
	# --- ActionController Extensions ---
	include ActionController::Cookies
	include ActionController::MimeResponds


	# --- Pundit Authorization ---
	include Pundit::Authorization

	# --- CSRF Protection (Disabled for API)---
	# include ActionController::RequestForgeryProtection
	# protect_from_forgery with: :null_session

	# --- Authentication handled by Authenticable concern ---
	include Authenticable

	# Ensures Pundit exceptions are handled gracefully
	rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

	# --- Custom Error Handling ---
	rescue_from CustomError::Unauthorized, with: :handle_unauthorized
	rescue_from CustomError::Forbidden, with: :handle_forbidden
	rescue_from CustomError::NotFound, with: :handle_not_found
	rescue_from CustomError::UnprocessableEntity, with: :handle_unprocessable_entity
	rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

	# --- Accessors --
	attr_reader :current_user

	private

	# Standard API response format
	def success_response(data: nil, message: 'Success', status: :ok, meta: {})
		response_body = {
			success: true,
			message: message
		}

		response_body[:data] = data if data.present?
		response_body[:meta] = meta if meta.present?

		render json: response_body, status: status
	end

	def error_response(message: 'An error occurred', errors: [], status: :unprocessable_content)
		render json: {
			success: false,
			message: message,
			errors: errors
		}, status: status
	end

	# Error Handlers
	def handle_not_found(e)
		Rails.logger.error "Not Found: #{e.message}"
		error_response(message: 'Resource not found', status: :not_found)
	end

	def user_not_authorized(e)
		Rails.logger.error "Not Authorized: #{e.message}"
    	message = "You are not authorized to #{e.query} this #{e.record.class.name.downcase}."
    	error_response(message: message, status: :forbidden)
  	end

	def handle_unauthorized(e)
		Rails.logger.error "Unauthorized: #{e.message}"
		error_response(message: e.message, status: :unauthorized)
	end

	def handle_forbidden(e)
		Rails.logger.error "Forbidden: #{e.message}"
		error_response(message: 'Forbidden', status: :forbidden)
	end

	def handle_unprocessable_entity(e)
		Rails.logger.error "Validation Error: #{e.message}"
		error_response(message: 'Validation Error', errors: format_validation_errors(e.record), status: :unprocessable_content)
	end

	# Format ActiveRecord validation errors
	def format_validation_errors(record)
		return [] unless record&.errors

		record.errors.map do |error|
			{ field: error.attribute.to_s, message: error.message }
		end
	end

	# Pagination helpers
	def pagination_meta(collection)
		{
			pagination: {
				current_page: collection.current_page,
				per_page: collection.per_page,
				total_pages: collection.total_pages,
				total_count: collection.total_count
			}
		}
	end

	# Request logging
	def log_request_info
		Rails.logger.info "#{request.method} #{request.path} - Params: #{params.except(:controller, :action)}"
	end
end
