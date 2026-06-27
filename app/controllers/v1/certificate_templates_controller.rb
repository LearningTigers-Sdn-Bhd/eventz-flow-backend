module V1
  class CertificateTemplatesController < ApplicationController
    before_action :set_event_and_authorize
    before_action :set_template, only: %i[show update destroy]

    # GET /v1/events/:event_id/certificate_template
    def show
      if @template
        render json: @template.as_json, status: :ok
      else
        render json: nil, status: :ok
      end
    end

    # POST /v1/events/:event_id/certificate_template
    def create
      @template = @event.certificate_template || @event.build_certificate_template
      authorize @template, :create?

      # Attach/purge the background image first so completeness validation
      # (e.g. status: ready) sees the final attachment state.
      @template.save(validate: false) if @template.new_record?
      handle_background_image

      if @template.update(template_params.except(:background_image, :remove_background_image))
        render json: @template.reload.as_json, status: :created
      else
        render json: { errors: @template.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:event_id/certificate_template
    def update
      @template ||= @event.certificate_template || @event.build_certificate_template
      authorize @template, :update?

      @template.save(validate: false) if @template.new_record?
      handle_background_image

      if @template.update(template_params.except(:background_image, :remove_background_image))
        render json: @template.reload.as_json, status: :ok
      else
        render json: { errors: @template.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/certificate_template
    def destroy
      authorize @template, :destroy? if @template
      @template&.destroy
      head :no_content
    end

    private

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      authorize @event, :show?
    end

    def set_template
      @template = @event.certificate_template
    end

    def handle_background_image
      tpl = params[:certificate_template] || {}

      if tpl[:background_image].present? && tpl[:background_image].respond_to?(:read)
        @template.background_image.attach(tpl[:background_image])
      elsif ActiveModel::Type::Boolean.new.cast(tpl[:remove_background_image])
        @template.background_image.purge_later if @template.background_image.attached?
      end
    end

    def template_params
      params.require(:certificate_template).permit(
        :status,
        :orientation,
        :canvas_width,
        :canvas_height,
        :background_image,
        :remove_background_image,
        fields: [
          :id,
          :type,
          :label,
          :x,
          :y,
          :width,
          :height,
          :font_size,
          :font_style,
          :color,
          :align,
          :static_value
        ]
      )
    end
  end
end
