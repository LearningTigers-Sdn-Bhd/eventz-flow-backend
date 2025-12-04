class V1::ExhibitionContractorProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_exhibition_contractor_profile, only: [:show, :update]

  # GET /v1/exhibition_contractor_profiles/:id
  def show
    authorize @exhibition_contractor_profile, policy_class: ExhibitionContractorProfilePolicy

    render json: format_profile(@exhibition_contractor_profile), status: :ok
  end

  # PATCH/PUT /v1/exhibition_contractor_profiles/:id
  def update
    authorize @exhibition_contractor_profile, policy_class: ExhibitionContractorProfilePolicy

    if @exhibition_contractor_profile.update(exhibition_contractor_profile_params)
      render json: format_profile(@exhibition_contractor_profile), status: :ok
    else
      render json: { errors: @exhibition_contractor_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_exhibition_contractor_profile
    @exhibition_contractor_profile = ExhibitionContractorProfile.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not Found', message: 'Exhibition contractor profile not found.' }, status: :not_found
  end

  def exhibition_contractor_profile_params
    params.require(:exhibition_contractor_profile).permit(:company_name, :contact_person, :contact_email, :contact_phone)
  end

  def format_profile(profile)
    {
      id: profile.id,
      user_id: profile.user_id,
      company_name: profile.company_name,
      contact_person: profile.contact_person,
      contact_email: profile.contact_email,
      contact_phone: profile.contact_phone,
      created_at: profile.created_at.iso8601,
      updated_at: profile.updated_at.iso8601
    }
  end
end
