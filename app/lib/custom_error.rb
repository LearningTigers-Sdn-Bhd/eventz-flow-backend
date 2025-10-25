class CustomError < StandardError
	attr_reader :status, :error, :message

	def initialize(error=nil, status=nil, message=nil)
		@error = error || 'Internal Server Error'
		@status = status || :internal_server_error
		@message = message || 'Something went wrong'
	end

	# Standard API Errors based on HTTP status codes
	class Unauthorized < CustomError
		def initialize(message = 'Unauthorized request. Token is missing or invalid.')
			super('Unauthorized', 401, message)
		end
	end

	class Forbidden < CustomError
		def initialize(message = 'Forbidden access. You do not have permission to perform this action.')
			super('Forbidden', 403, message)
		end
	end

	class NotFound < CustomError
		def initialize(message = 'Not found. The requested resource does not exist.')
			super('Not Found', 404, message)
		end
	end

	class UnprocessableEntity < CustomError
		def initialize(message = 'Unprocessable entity. The request was well-formed but was unable to be followed due to semantic errors.', errors=nil)
			super('Unprocessable Entity', 422, message, errors)
		end
	end
end
