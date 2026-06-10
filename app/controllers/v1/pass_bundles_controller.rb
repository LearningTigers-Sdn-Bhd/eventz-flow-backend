module V1
  class PassBundlesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_pass_bundle, only: %i[show update destroy]

    def index
      authorize PassBundle.new(event: @event), :index?

      bundles = policy_scope(@event.pass_bundles)
                .includes(:registration_form, :ticket_type)
                .order(:name)

      render json: bundles.map { |bundle| format_response(bundle) }, status: :ok
    end

    def show
      authorize @pass_bundle
      render json: format_response(@pass_bundle), status: :ok
    end

    def create
      bundle = @event.pass_bundles.build(pass_bundle_params)
      bundle.created_by = current_user
      authorize bundle

      if bundle.save
        render json: format_response(bundle), status: :created
      else
        render json: { errors: bundle.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      authorize @pass_bundle

      if @pass_bundle.update(pass_bundle_params)
        render json: format_response(@pass_bundle), status: :ok
      else
        render json: { errors: @pass_bundle.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      authorize @pass_bundle
      @pass_bundle.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.with_deleted.find(params[:event_id])
    end

    def set_pass_bundle
      @pass_bundle = @event.pass_bundles.find(params[:id])
    end

    def pass_bundle_params
      params.require(:pass_bundle).permit(
        :name,
        :registration_form_id,
        :ticket_type_id,
        :pass_limit,
        :payment_mode,
        :payment_status,
        :status,
        :expires_at
      )
    end

    def format_response(bundle)
      {
        id: bundle.id,
        event_id: bundle.event_id,
        name: bundle.name,
        token: bundle.token,
        pass_limit: bundle.pass_limit,
        used_count: bundle.used_count,
        remaining_count: bundle.remaining_count,
        payment_mode: bundle.payment_mode,
        payment_status: bundle.payment_status,
        status: bundle.status,
        expires_at: bundle.expires_at&.iso8601,
        registration_form: {
          id: bundle.registration_form.id,
          name: bundle.registration_form.name,
          slug: bundle.registration_form.slug
        },
        ticket_type: {
          id: bundle.ticket_type.id,
          name: bundle.ticket_type.name
        },
        bundle_link: bundle_link(bundle),
        created_at: bundle.created_at,
        updated_at: bundle.updated_at
      }
    end

    def bundle_link(bundle)
      base_url = public_registration_url_for(@event)
      "#{base_url}/register/#{bundle.registration_form.slug}?bundle=#{bundle.token}"
    end
  end
end
