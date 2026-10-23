# frozen_string_literal: true

module V1
  module Public
    # Polled by the panel on every page, so it is cached briefly and exposes
    # only the message, and only while the notice is switched on.
    class SystemNoticesController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def show
        expires_in 30.seconds, public: true

        render json: { data: { message: SystemNotice.current.public_message } }, status: :ok
      end
    end
  end
end
