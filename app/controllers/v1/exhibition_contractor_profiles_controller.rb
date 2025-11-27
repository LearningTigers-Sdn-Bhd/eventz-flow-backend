class V1::ExhibitionContractorProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_exhibition_contractor_profile, only: [:show, :update, :destroy]

  # GET /v1/exhibition_contractor_profiles
  def index
    # Policy authorization will be added here
    # authorize ExhibitionContractorProfile

    exhibition_contractor_profiles = ExhibitionContractorProfile.all
    render json: exhibition_contractor_profiles, status: :ok
  end

  # GET /v1/exhibition_contractor_profiles/:id
  def show
    # Policy authorization will be added here
    # authorize @exhibition_contractor_profile
    render json: @exhibition_contractor_profile, status: :ok
  end

  # POST /v1/exhibition_contractor_profiles
  def create
    # Policy authorization will be added here
    # authorize ExhibitionContractorProfile

    @exhibition_contractor_profile = ExhibitionContractorProfile.new(exhibition_contractor_profile_params)

    if @exhibition_contractor_profile.save
      render json: @exhibition_contractor_profile, status: :created
    else
      render json: { errors: @exhibition_contractor_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /v1/exhibition_contractor_profiles/:id
  def update
    # Policy authorization will be added here
    # authorize @exhibition_contractor_profile

    if @exhibition_contractor_profile.update(exhibition_contractor_profile_params)
      render json: @exhibition_contractor_profile, status: :ok
    else
      render json: { errors: @exhibition_contractor_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /v1/exhibition_contractor_profiles/:id
  def destroy
    # Policy authorization will be added here
    # authorize @exhibition_contractor_profile

    @exhibition_contractor_profile.destroy
    head :no_content
  end

  private

  def set_exhibition_contractor_profile
    @exhibition_contractor_profile = ExhibitionContractorProfile.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not Found', message: 'Exhibition contractor profile not found.' }, status: :not_found
  end

  def exhibition_contractor_profile_params
    params.require(:exhibition_contractor_profile).permit(:company_name, :contact_person, :contact_email, :contact_phone, :user_id)
  end
end