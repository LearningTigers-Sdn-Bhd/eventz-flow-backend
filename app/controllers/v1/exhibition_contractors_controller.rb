module V1
  class ExhibitionContractorsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_exhibition_contractor, only: [:show, :update, :toggle_status, :destroy, :assigned_events]

    # GET /v1/exhibition_contractors
    def index
      authorize User.new(role: :exhibition_contractor), :index?, policy_class: ExhibitionContractorPolicy

      contractors = policy_scope(User).where(role: :exhibition_contractor)

      render json: contractors.map { |contractor| format_contractor(contractor) }, status: :ok
    end

    # GET /v1/exhibition_contractors/available
    # Returns all active contractors for assignment to events (bypasses created_by scope)
    def available
      authorize User.new(role: :exhibition_contractor), :available?, policy_class: ExhibitionContractorPolicy

      contractors = User.where(role: :exhibition_contractor, status: :active)

      render json: contractors.map { |contractor| format_contractor(contractor) }, status: :ok
    end

    # GET /v1/exhibition_contractors/:id
    def show
      authorize @contractor, :show?, policy_class: ExhibitionContractorPolicy

      render json: format_contractor(@contractor), status: :ok
    end

    # POST /v1/exhibition_contractors
    def create
      contractor_params = params.require(:exhibition_contractor).permit(
        :full_name, :email, :phone, :password, :password_confirmation, :created_by_id
      )

      # Allow org_owner to specify created_by_id, otherwise use current_user
      assigned_created_by_id = if current_user.org_owner? && contractor_params[:created_by_id].present?
        contractor_params[:created_by_id]
      else
        current_user.id
      end

      contractor_user = User.new(
        full_name: contractor_params[:full_name],
        email: contractor_params[:email],
        phone: contractor_params[:phone],
        password: contractor_params[:password],
        password_confirmation: contractor_params[:password_confirmation],
        role: :exhibition_contractor,
        status: :active,
        email_verified_at: Time.current,
        created_by_id: assigned_created_by_id
      )

      authorize contractor_user, :create?, policy_class: ExhibitionContractorPolicy

      ActiveRecord::Base.transaction do
        contractor_user.save!
        contractor_user.reload # Ensure profile created by callback is loaded

        profile_params = params.require(:exhibition_contractor).permit(
          exhibition_contractor_profile_attributes: [:company_name, :contact_person, :contact_email, :contact_phone, :allow_printing_services, :standard_package_info]
        )[:exhibition_contractor_profile_attributes]

        if profile_params.present?
          if contractor_user.exhibition_contractor_profile.present?
            contractor_user.exhibition_contractor_profile.update!(profile_params)
          else
            contractor_user.create_exhibition_contractor_profile!(profile_params)
          end
        end

        render json: format_contractor(contractor_user), status: :created
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Validation Error', errors: e.record.errors.full_messages },
             status: :unprocessable_content
    end

    # PUT/PATCH /v1/exhibition_contractors/:id
    def update
      authorize @contractor, :update?, policy_class: ExhibitionContractorPolicy

      ActiveRecord::Base.transaction do
        @contractor.update!(contractor_update_params)

        profile_params = params.dig(:exhibition_contractor, :exhibition_contractor_profile_attributes)
        if profile_params.present? && @contractor.exhibition_contractor_profile
          @contractor.exhibition_contractor_profile.update!(profile_params.permit(
            :company_name, :contact_person, :contact_email, :contact_phone, :guidelines_pdf, :allow_printing_services, :standard_package_info
          ))
        end

        render json: format_contractor(@contractor), status: :ok
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Validation failed', errors: e.record.errors.full_messages },
             status: :unprocessable_content
    end

    # PATCH /v1/exhibition_contractors/:id/toggle_status
    def toggle_status
      authorize @contractor, :toggle_status?, policy_class: ExhibitionContractorPolicy

      unless params[:status].in?(['active', 'inactive'])
        return render json: { error: 'Invalid status value' }, status: :unprocessable_content
      end

      if @contractor.update(status: params[:status])
        render json: format_contractor(@contractor), status: :ok
      else
        render json: { error: 'Validation failed', errors: @contractor.errors.full_messages },
               status: :unprocessable_content
      end
    end

    # GET /v1/exhibition_contractors/:id/assigned_events
    def assigned_events
      authorize @contractor, :show?, policy_class: ExhibitionContractorPolicy

      profile = @contractor.exhibition_contractor_profile
      
      if profile.nil?
        return render json: [], status: :ok
      end

      events = Event.joins(:event_exhibition_contractor)
                    .where(event_exhibition_contractors: { exhibition_contractor_profile_id: profile.id })

      render json: events.map { |event| format_event(event) }, status: :ok
    end

    # DELETE /v1/exhibition_contractors/:id
    def destroy
      authorize @contractor, :destroy?, policy_class: ExhibitionContractorPolicy

      return render_cannot_delete_self if deleting_self?

      @contractor.destroy
      render json: format_contractor(@contractor), status: :ok
    end

    private

    def set_exhibition_contractor
      @contractor = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Exhibition contractor not found' }, status: :not_found
    end

    def contractor_update_params
      permitted = params.require(:exhibition_contractor).permit(:full_name, :email, :phone)

      if params[:exhibition_contractor][:password].present?
        permitted.merge!(
          params.require(:exhibition_contractor).permit(:password, :password_confirmation)
        )
      end

      # Allow org_owner to update created_by_id
      if current_user.org_owner? && params[:exhibition_contractor][:created_by_id].present?
        permitted.merge!(
          params.require(:exhibition_contractor).permit(:created_by_id)
        )
      end

      permitted
    end

    def format_contractor(contractor)
      profile = contractor.exhibition_contractor_profile

      {
        id: contractor.id,
        email: contractor.email,
        full_name: contractor.full_name,
        phone: contractor.phone,
        role: contractor.role,
        status: contractor.status,
        created_at: contractor.created_at.iso8601,
        updated_at: contractor.updated_at.iso8601,
        created_by_id: contractor.created_by_id,
        exhibition_contractor_profile: profile ? format_profile(profile) : nil
      }
    end

    def format_profile(profile)
      {
        id: profile.id,
        user_id: profile.user_id,
        company_name: profile.company_name,
        contact_person: profile.contact_person,
        contact_email: profile.contact_email,
        contact_phone: profile.contact_phone,
        allow_printing_services: profile.allow_printing_services,
        standard_package_info: profile.standard_package_info,
        guidelines_pdf_url: profile.guidelines_pdf.attached? ? url_for(profile.guidelines_pdf) : nil,
        guidelines_pdf_filename: profile.guidelines_pdf.attached? ? profile.guidelines_pdf.filename.to_s : nil,
        created_at: profile.created_at.iso8601,
        updated_at: profile.updated_at.iso8601
      }
    end

    def format_event(event)
      {
        id: event.id,
        title: event.title,
        description: event.description,
        status: event.status,
        start_date: event.start_date&.iso8601,
        end_date: event.end_date&.iso8601,
        created_at: event.created_at.iso8601,
        updated_at: event.updated_at.iso8601
      }
    end

    def deleting_self?
      @contractor.id == current_user.id
    end

    def render_cannot_delete_self
      render json: { error: 'You cannot delete your own account' }, status: :unprocessable_content
    end
  end
end
