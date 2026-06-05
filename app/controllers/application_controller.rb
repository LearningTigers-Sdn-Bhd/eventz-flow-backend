require Rails.root.join('app/lib/custom_error')
require Rails.root.join('app/lib/public_registration_error_page_renderer')
require Rails.root.join('app/services/jwt_service')
require Rails.root.join('app/services/authentication_service')

class ApplicationController < ActionController::API
	# --- ActionController Extensions ---
	include ActionController::Cookies
	include ActionController::MimeResponds

	# --- Pundit Authorization ---
	include Pundit::Authorization
	
	# --- Pagy Pagination ---
	include Pagy::Method

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
	
	# --- Pagy Error Handling ---
	# Pagy 43+ uses OptionError for invalid parameters (limit, page, etc.)
	# Overflow is handled by configuration (:empty_page), so no error is raised.
	rescue_from Pagy::OptionError, with: :handle_pagy_option_error

	# --- Accessors --
	attr_reader :current_user

	# Pundit user context — wraps current_user with optional api_key for policy scopes
	def pundit_user
		return current_user unless @current_api_key
		PunditUserContext.new(current_user, @current_api_key)
	end

	private

	# Standard API response format
	def success_response(data: nil, message: 'Success', status: :ok, meta: {}, pagination: nil)
		response_body = {
			success: true,
			message: message
		}

		response_body[:data] = data if data.present?
		response_body[:meta] = meta if meta.present?
		response_body[:pagination] = pagination if pagination.present?

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
	
	# Pagy Handlers
	def handle_pagy_option_error(exception)
		render json: {
			error: 'invalid_pagination_params',
			message: exception.message
		}, status: :bad_request
	end

	# Format ActiveRecord validation errors
	def format_validation_errors(record)
		return [] unless record&.errors

		record.errors.map do |error|
			{ field: error.attribute.to_s, message: error.message }
		end
	end

	# Request logging
	def log_request_info
		Rails.logger.info "#{request.method} #{request.path} - Params: #{params.except(:controller, :action)}"
	end

	def render_public_registration_error_page(title: 'Unable to Complete Payment Redirect', message:)
		render html: PublicRegistrationErrorPageRenderer.call(title: title, message: message).html_safe,
		       status: :unprocessable_content,
		       layout: false
	end

	# Generate pagination metadata for API responses
	def pagy_metadata(pagy)
		{
			current_page: pagy.page,
			total_pages: pagy.pages,
			total_count: pagy.count,
			per_page: pagy.limit,
			prev_page: pagy.previous,
			next_page: pagy.next,
			first_page: 1,
			last_page: pagy.pages,
			from: pagy.from,
			to: pagy.to
		}
	end

	# Sanitize pagination parameters
	def pagination_params
		params.slice(:page, :per_page).permit(:page, :per_page).tap do |p|
			p[:page] = [p[:page].to_i, 1].max if p[:page].present?
			p[:per_page] = [[p[:per_page].to_i, 100].min, 1].max if p[:per_page].present?
		end
	end
end
