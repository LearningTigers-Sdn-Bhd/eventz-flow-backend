class V1::RefreshController < ApplicationController
    skip_before_action :authenticate_request!, only: [:refresh]

    # POST /v1/refresh (To refresh access token using refresh token)
    def refresh
        # Find refresh token record
        token_record = RefreshToken.find_by(token_hash: refresh_token)

        unless token_record
            raise CustomError::Unauthorized.new('User not found')
        end

        user = token_record.user

        # Generate new access token
        new_access_token = JsonWebToken.encode(user_id: user.id)
        render json: { access_token: new_access_token }, status: :ok
    end

    private

    def refresh_token
        request.headers['HTTP_X_REFRESH_TOKEN'] ||
            request.headers['HTTP_X_REFRESH_TOKEN'] ||
            cookies['refresh_token']
    end
end
