require Rails.root.join('app/lib/custom_error')
require Rails.root.join('app/services/json_web_token')

class ApplicationController < ActionController::API
	# --- Pundit Authorization ---
	include Pundit::Authorization

	# Ensures Pundit exceptions are handled gracefully
	rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

	# --- JWT Authentication (Run before every action unless skipped) ---
	before_action :authenticate_request!

	# --- Custom Error Handling ---
	rescue_from CustomError::Unauthorized, with: :handle_unauthorized
	rescue_from CustomError::Forbidden, with: :handle_forbidden
	rescue_from CustomError::NotFound, with: :handle_not_found
	rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

	# --- Accessors --
	attr_reader :current_user

	private

	# --- JWT Authentication Logic ---

	def authenticate_request!
		# Get the token from the Authorization header (Bearer <token>)
		header = request.headers['Authorization']
		# Extract the token string
		header = header.split(' ').last if header

		# Check for token existence and validity
		begin
			@decoded = JsonWebToken.decode(header)
			# Find the user by user_id stored in the token payload
			@current_user = User.find(@decoded[:user_id])
		rescue CustomError::Unauthorized => e
			# Re-raise the custom error for the rescue_from handler to catch
			raise e
		rescue ActiveRecord::RecordNotFound
			# If user_id is in token but user does not exist (e.g., deleted), unauthorized
			raise CustomError::Unauthorized.new('User associated with token is not found.')
		end
	end


	# --- Pundit Error Handler ---

	def user_not_authorized(exception)
		policy_name = exception.policy.class.to_s.underscore
		message = I18n.t("#{policy_name}.#{exception.query}", scope: 'pundit', default: :default)

		# Raise custom forbidden error
		raise CustomError::Forbidden.new(message)
	end

	# --- Custom API Error Responses (Private Handlers) ---

	def handle_unauthorized(e)
		render json: { error: e.error, message: e.message }, status: :unauthorized
	end

	def handle_forbidden(e)
		render json: { error: e.error, message: e.message }, status: :forbidden
	end

	def handle_not_found(e)
		render json: { error: 'Not Found', message: e.message }, status: :not_found
	end
end
