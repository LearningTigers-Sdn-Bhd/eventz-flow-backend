require Rails.root.join('app/lib/custom_error')
require Rails.root.join('app/services/json_web_token')
require Rails.root.join('app/services/authentication_service')

class ApplicationController < ActionController::API
	# --- Pundit Authorization ---
	include Pundit::Authorization
	include ActionController::Cookies
	include ActionController::RequestForgeryProtection
	protect_from_forgery with: :null_session

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

	# def authenticate_request!
	# 	# Get the token from the Authorization header (Bearer <token>)
	# 	header = request.headers['Authorization']
	# 	# Extract the token string
	# 	header = header.split(' ').last if header

	# 	# Check for token existence and validity
	# 	begin
	# 		@decoded = JsonWebToken.decode(header)
	# 		# Find the user by user_id stored in the token payload
	# 		@current_user = User.find(@decoded[:user_id])
	# 	rescue CustomError::Unauthorized => e
	# 		# Re-raise the custom error for the rescue_from handler to catch
	# 		raise e
	# 	rescue ActiveRecord::RecordNotFound
	# 		# If user_id is in token but user does not exist (e.g., deleted), unauthorized
	# 		raise CustomError::Unauthorized.new('User associated with token is not found.')
	# 	end
	# end

	def authenticate_request!
	  header = request.headers['Authorization']
	  return render json: { error: 'Missing token' }, status: :unauthorized unless header

	  # Try JWT first (standard Bearer)
	  if header.start_with?('Bearer ')
	    token = header.split(' ').last
	    begin
	      decoded_token = JsonWebToken.decode(token)
	      @current_user = User.find_by(id: decoded_token[:user_id])
	      return if @current_user.present?
	    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
	      # fallback to API key check next
	    end
	  end

	  # Try raw API Key (no Bearer prefix) - use BCrypt-based authentication
	  if header.length > 30 && !header.include?(' ')
	    @current_user = ApiKey.authenticate_by_key(header)
	    return if @current_user.present?
	  end

	# Old API Key authentication logic
	
	#   if header.length > 30 && !header.include?(' ')
	#     hashed_key = AuthenticationService.hash_token(header)
	#     api_key_record = ::ApiKey.find_by(key_hash: hashed_key, is_active: true)
	#     if api_key_record
	#       api_key_record.touch(:last_used_at)
	#       @current_user = api_key_record.user
	#       return
	#     end
	#   end

	  render json: { error: 'Unauthorized', message: 'Invalid token' }, status: :unauthorized
	end

	# The core dual-authentication logic
	# def authenticate_via_jwt_or_api_key
	#     header = request.headers['Authorization']
	#     return nil unless header

	#     # 1. Prioritize checking for the Bearer token format (standard for JWT)
	#     if header.start_with?('Bearer ')
	#         token = header.split(' ').last

	#         # A. Try JWT Access Token first (for logged-in sessions)
	#         user = authenticate_via_jwt(token)
	#         return user if user

	#         # B. Fallback: Check if the value could be an API Key
	#         return authenticate_via_api_key(token)

	#     # 2. Check for raw API Key (long string passed directly in the header)
	#     elsif header.length > 30 && !header.include?(' ')
	#         return authenticate_via_api_key(header)
	#     end

	#     nil
	# end

	# # Helper to validate JWT
	# def authenticate_via_jwt(token)
	#     decoded_token = JsonWebToken.decode(token)
	#     User.find_by(id: decoded_token[:user_id])
	# rescue CustomError::Unauthorized
	#     nil
	# rescue ActiveRecord::RecordNotFound
	#     nil
	# end

	# # Helper to validate API Key
	# def authenticate_via_api_key(api_key_string)
	#     return nil unless api_key_string.present?

	#     hashed_key = AuthenticationService.hash_token(api_key_string)

	#     # Use the fully qualified name to ensure the model is found
	#     api_key_record = ::ApiKey.find_by(key_hash: hashed_key, is_active: true)
	#     return nil unless api_key_record

	#     api_key_record.touch(:last_used_at)
	#     api_key_record.user
	# end


	# --- Pundit Error Handler ---

	# def user_not_authorized(exception)
	# 	policy_name = exception.policy.class.to_s.underscore
	# 	message = I18n.t("#{policy_name}.#{exception.query}", scope: 'pundit', default: :default)

	# 	# Raise custom forbidden error
	# 	raise CustomError::Forbidden.new(message)
	# end
	def user_not_authorized(exception)
    	message = "You are not authorized to #{exception.query} this #{exception.record.class.name.downcase}."
    	render json: { error: message }, status: :forbidden
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

	private
	def header_token
		header = request.headers['Authorization']
		return nil unless header
		header.split(' ').last
	end
end
