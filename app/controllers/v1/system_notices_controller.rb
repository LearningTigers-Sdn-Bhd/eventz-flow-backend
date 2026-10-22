module V1
  class SystemNoticesController < ApplicationController
    def show
      authorize SystemNotice

      render json: { data: serialize(SystemNotice.current) }, status: :ok
    end

    def update
      authorize SystemNotice

      notice = SystemNotice.current
      if notice.update(notice_params)
        render json: { data: serialize(notice) }, status: :ok
      else
        render json: { errors: notice.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def notice_params
      params.permit(:message, :active)
    end

    def serialize(notice)
      { message: notice.message, active: notice.active }
    end
  end
end
