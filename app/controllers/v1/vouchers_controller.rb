module V1
  class VouchersController < ApplicationController
    before_action :set_voucher, only: [:show, :update, :destroy]
    before_action :authorize_resource, only: [:show, :update, :destroy]
    before_action :ensure_voucher_enabled_for_resource!, only: [:show, :update, :destroy]
    before_action :ensure_voucher_enabled_for_create!, only: [:create]

    # GET /api/v1/vouchers
    def index
      @vouchers = policy_scope(Voucher)

      # Apply filters if provided in query parameters
      if params[:event_id].present?
        event = Event.friendly.find(params[:event_id])
        ensure_voucher_enabled!(event)
        return if performed?
        @vouchers = @vouchers.where(event_id: event.id)
      elsif filter_params.key?(:vendor_id)
        @vouchers = @vouchers.where(vendor_id: filter_params[:vendor_id])
      elsif filter_params.key?(:event_id)
        event = Event.find(filter_params[:event_id])
        ensure_voucher_enabled!(event)
        return if performed?
        @vouchers = @vouchers.where(event_id: event.id)
      end

      @vouchers = @vouchers.joins(:event).where(events: { use_voucher: true })

      success_response(data: @vouchers.includes(:vendor).map { |v| format_voucher(v) })
    end

    # GET /api/v1/vouchers/:id
    def show
      success_response(data: format_voucher(@voucher))
    end

    # POST /api/v1/vouchers
    def create
      @voucher = Voucher.new(voucher_params)
      authorize @voucher

      # Handle image upload via Active Storage
      handle_image_attachment

      if @voucher.save
        success_response(data: format_voucher(@voucher), status: :created, message: 'Voucher created successfully')
      else
        error_response(
          message: 'Validation failed',
          errors: @voucher.errors.full_messages,
          status: :unprocessable_content
        )
      end
    end

    # PATCH/PUT /api/v1/vouchers/:id
    def update
      # Handle image upload/removal via Active Storage
      handle_image_attachment

      if @voucher.update(voucher_params)
        success_response(data: format_voucher(@voucher), status: :ok, message: 'Voucher updated successfully')
      else
        error_response(
          message: 'Validation failed',
          errors: @voucher.errors.full_messages,
          status: :unprocessable_content
        )
      end
    end

    # DELETE /api/v1/vouchers/:id
    def destroy
      @voucher.destroy
      success_response(status: :no_content, message: 'Voucher deleted successfully')
    end

    private

    def authorize_resource
      authorize @voucher
    end

    def set_voucher
      @voucher = Voucher.find(params[:id])
    end

    # Handle image upload and removal via Active Storage
    def handle_image_attachment
      # New image upload
      if params[:image].present? && params[:image].respond_to?(:read)
        @voucher.image.attach(params[:image])
        return
      end

      # Image removal (accepts boolean true, string "true", or "1")
      if ActiveModel::Type::Boolean.new.cast(params[:remove_image])
        @voucher.image.purge_later if @voucher.image.attached?
      end
    end

    def voucher_params
      params.permit(
        :vendor_id,
        :event_id,
        :title,
        :description,
        :voucher_code,
        :status,
        :start_date,
        :end_date,
        :start_time,
        :end_time,
        :total_redemption_available,
        :is_unlimited,
        :max_redemptions_per_user,
        :voucher_type,
        :voucher_value,
        :voucher_category
      )
    end

    def filter_params
      params.permit(:vendor_id, :event_id)
    end

    def ensure_voucher_enabled_for_create!
      event_id = params[:event_id] || params.dig(:voucher, :event_id)
      return if event_id.blank?

      event = Event.find(event_id)
      ensure_voucher_enabled!(event)
    end

    def ensure_voucher_enabled_for_resource!
      ensure_voucher_enabled!(@voucher.event)
    end

    def ensure_voucher_enabled!(event)
      return if event.use_voucher?

      error_response(
        message: "Voucher feature is unavailable for this event.",
        status: :forbidden
      )
    end

    def format_voucher(voucher)
      voucher.as_json(
        include: { vendor: { only: [:id, :full_name, :email, :phone] } }
      ).merge(image_url: voucher.image.attached? ? url_for(voucher.image) : nil)
    end
  end
end
