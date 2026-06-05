module V1
  class RegistrationFormsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event_and_authorize
    before_action :set_registration_form, only: [:show, :update, :destroy]

    # GET /v1/events/:event_id/registration_forms
    def index
      @registration_forms = @event.registration_forms
        .includes(:registration_form_rsvp_setting, registration_form_ticket_types: :ticket_type)
        .order(:position)
      render json: @registration_forms.map { |form| format_response(form) }, status: :ok
    end

    # GET /v1/events/:event_id/registration_forms/:id
    def show
      render json: format_response(@registration_form), status: :ok
    end

    # POST /v1/events/:event_id/registration_forms
    def create
      authorize @event, :update?

      @registration_form = @event.registration_forms.build(registration_form_params)

      rules = normalized_ticket_type_rules

      if rules.present?
        error = validate_ticket_type_rules(rules)
        if error
          render json: { errors: [error] }, status: :unprocessable_content and return
        end
      end

      if @registration_form.save
        if rules.present?
          sync_errors = sync_ticket_type_rules(rules)
          if sync_errors.any?
            @registration_form.destroy
            return render json: { errors: sync_errors }, status: :unprocessable_content
          end
        end

        render json: format_response(@registration_form.reload), status: :created
      else
        render json: { errors: @registration_form.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:event_id/registration_forms/:id
    def update
      authorize @event, :update?

      rules = normalized_ticket_type_rules

      if rules.present?
        error = validate_ticket_type_rules(rules)
        if error
          render json: { errors: [error] }, status: :unprocessable_content and return
        end
      end

      if @registration_form.update(registration_form_params)
        if params[:registration_form].key?(:ticket_type_ids) || params[:registration_form].key?(:ticket_type_rules)
          sync_errors = sync_ticket_type_rules(rules || [])
          if sync_errors.any?
            return render json: { errors: sync_errors }, status: :unprocessable_content
          end
        end
        render json: format_response(@registration_form.reload), status: :ok
      else
        render json: { errors: @registration_form.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/registration_forms/:id
    def destroy
      authorize @event, :update?
      @registration_form.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.with_deleted.find(params[:event_id])
    end

    def set_event_and_authorize
      set_event
      authorize @event, :show?
    end

    def set_registration_form
      @registration_form = @event.registration_forms.find(params[:id])
    end

    def registration_form_params
      attrs = permitted_registration_form_payload.slice(
        :slug,
        :name,
        :description,
        :status,
        :position,
      )

      attrs[:custom_labels_data] = normalize_custom_labels_data(
        permitted_registration_form_payload[:custom_labels_data],
      )

      attrs
    end

    def permitted_registration_form_payload
      @permitted_registration_form_payload ||= params.require(:registration_form).permit(
        :slug,
        :name,
        :description,
        :status,
        :position,
        custom_labels_data: [:key, :label],
        ticket_type_ids: [],
        ticket_type_rules: [
          :ticket_type_id,
          :registration_mode,
          :min_attendees,
          :max_attendees,
          { custom_labels_data: [:key, :label] },
        ],
      )
    end

    def ticket_type_ids_param
      permitted_registration_form_payload[:ticket_type_ids]
    end

    def ticket_type_rules_param
      permitted_registration_form_payload[:ticket_type_rules]
    end

    def normalized_ticket_type_rules
      rules = ticket_type_rules_param
      ids = ticket_type_ids_param

      if rules.present?
        return rules.map do |rule|
          {
            ticket_type_id: rule[:ticket_type_id].to_i,
            registration_mode: (rule[:registration_mode] || 'single').to_s,
            min_attendees: (rule[:min_attendees] || 1).to_i,
            max_attendees: rule[:max_attendees].presence&.to_i,
            custom_labels_data: normalize_custom_labels_data(rule[:custom_labels_data]),
          }
        end
      end

      return nil unless ids.present?

      ids.map do |ticket_type_id|
        {
          ticket_type_id: ticket_type_id.to_i,
          registration_mode: 'single',
          min_attendees: 1,
          max_attendees: nil,
          custom_labels_data: [],
        }
      end
    end

    def validate_ticket_type_rules(rules)
      return if rules.blank?

      ids = rules.map { |rule| rule[:ticket_type_id].to_i }

      if ids.uniq.length != ids.length
        return 'Duplicate ticket_type_id found in ticket_type_rules'
      end

      valid_ids = @event.ticket_types.where(id: ids).pluck(:id)
      invalid_ids = ids - valid_ids
      if invalid_ids.any?
        "Ticket types #{invalid_ids.join(', ')} do not belong to this event"
      end
    end

    def sync_ticket_type_rules(rules)
      sync_errors = []

      ActiveRecord::Base.transaction do
        desired_ids = rules.map { |rule| rule[:ticket_type_id].to_i }
        @registration_form.registration_form_ticket_types.where.not(ticket_type_id: desired_ids).destroy_all

        rules.each do |rule|
          mapping = @registration_form.registration_form_ticket_types.find_or_initialize_by(
            ticket_type_id: rule[:ticket_type_id].to_i,
          )

          mapping.assign_attributes(
            registration_mode: rule[:registration_mode],
            min_attendees: rule[:min_attendees],
            max_attendees: rule[:max_attendees],
            custom_labels_data: rule[:custom_labels_data] || [],
          )

          unless mapping.save
            sync_errors.concat(mapping.errors.full_messages)
            raise ActiveRecord::Rollback
          end
        end
      end

      sync_errors
    end

    def format_response(form)
      mappings = form.registration_form_ticket_types.includes(:ticket_type)
      rsvp_setting = form.registration_form_rsvp_setting

      {
        id: form.id,
        event_id: form.event_id,
        name: form.name,
        slug: form.slug,
        description: form.description,
        custom_labels_data: form.custom_labels_data || [],
        status: RegistrationForm.statuses[form.status],
        position: form.position,
        registration_form_rsvp_setting: rsvp_setting&.as_json(
          only: %i[
            id
            registration_form_id
            enabled
            rsvp_required
            rsvp_expires_in_hours
            review_sla_hours
            notify_by_date
            created_at
            updated_at
          ]
        ),
        created_at: form.created_at,
        updated_at: form.updated_at,
        ticket_types: mappings.map { |mapping|
          tt = mapping.ticket_type

          {
            id: tt.id,
            name: tt.name,
            price: tt.price.to_f,
            status: tt.status,
            registration_mode: mapping.registration_mode,
            min_attendees: mapping.min_attendees,
            max_attendees: mapping.max_attendees,
            custom_labels_data: mapping.custom_labels_data || [],
          }
        }
      }
    end

    def normalize_custom_labels_data(value)
      return [] if value.blank?

      items = if value.respond_to?(:to_a)
                value.to_a
              else
                []
              end

      return [] unless items.is_a?(Array)

      items.filter_map do |item|
        next unless item.is_a?(Hash) || item.respond_to?(:to_h)

        item = item.to_h if item.respond_to?(:to_h)
        key = item["key"].presence || item[:key].presence
        label = item["label"].presence || item[:label].presence

        next if key.blank? || label.blank?

        { "key" => key.to_s, "label" => label.to_s }
      end
    end
  end
end
