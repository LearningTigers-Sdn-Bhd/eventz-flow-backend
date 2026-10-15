module V1
  class CertificateTemplatesController < ApplicationController
    before_action :set_event_and_authorize
    before_action :set_template, only: %i[show update destroy]

    # GET /v1/events/:event_id/certificate_templates
    def index
      authorize @event, :show?, policy_class: CertificateTemplatePolicy
      render json: @event.certificate_templates.order(:id).map(&:as_json), status: :ok
    end

    # GET /v1/events/:event_id/certificate_templates/:id
    def show
      authorize @template, :show?
      render json: @template.as_json, status: :ok
    end

    # POST /v1/events/:event_id/certificate_templates
    # Body: { certificate_template: {...}, duplicate_from_id: Integer (optional) }
    # duplicate_from_id copies design (fields, canvas, background) from another
    # template of this event, so only the wording needs changing.
    def create
      @template = @event.certificate_templates.build
      authorize @template, :create?

      source = duplicate_source
      return render json: { errors: ['Template to duplicate not found'] }, status: :not_found if params[:duplicate_from_id].present? && source.nil?

      copy_design_from(source) if source

      # Attach/purge the background image first so completeness validation
      # (e.g. status: ready) sees the final attachment state.
      @template.save(validate: false)
      handle_background_image

      if @template.update(template_params.except(:background_image, :remove_background_image))
        render json: @template.reload.as_json, status: :created
      else
        @template.destroy
        render json: { errors: @template.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:event_id/certificate_templates/:id
    def update
      authorize @template, :update?

      handle_background_image

      if @template.update(template_params.except(:background_image, :remove_background_image))
        render json: @template.reload.as_json, status: :ok
      else
        render json: { errors: @template.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/certificate_templates/:id
    def destroy
      authorize @template, :destroy?
      @template.destroy
      head :no_content
    end

    private

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      authorize @event, :show?
    end

    def set_template
      @template = @event.certificate_templates.find(params[:id])
    end

    def duplicate_source
      @event.certificate_templates.find_by(id: params[:duplicate_from_id]) if params[:duplicate_from_id].present?
    end

    def copy_design_from(source)
      @template.assign_attributes(
        orientation: source.orientation,
        canvas_width: source.canvas_width,
        canvas_height: source.canvas_height,
        fields: source.fields
      )
      @template.save(validate: false)
      return unless source.background_image.attached?

      # A fresh blob, not a shared one: purging one template's image must not
      # delete the other's.
      blob = source.background_image.blob
      @template.background_image.attach(
        io: StringIO.new(blob.download), filename: blob.filename.to_s, content_type: blob.content_type
      )
    end

    def handle_background_image
      tpl = params[:certificate_template] || {}

      if tpl[:background_image].present? && tpl[:background_image].respond_to?(:read)
        @template.background_image.attach(tpl[:background_image])
      elsif ActiveModel::Type::Boolean.new.cast(tpl[:remove_background_image])
        if @template.background_image.attached?
          @template.background_image.purge_later
          # A template can't be "ready" without a background, so downgrade to
          # draft to keep the record in a valid, consistent state.
          @template.status = :draft if @template.ready?
        end
      end
    end

    def template_params
      params.require(:certificate_template).permit(
        :status,
        :name,
        :require_feedback,
        :orientation,
        :canvas_width,
        :canvas_height,
        :background_image,
        :remove_background_image,
        ticket_type_ids: [],
        auto_send_filter: [:key, { values: [] }],
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
