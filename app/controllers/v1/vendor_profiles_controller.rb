module V1
  class VendorProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_group
    before_action :set_vendor_affiliate
    before_action :authorize_group_vendor!
    before_action :set_vendor_profile, only: [:update]

    # PATCH /v1/groups/:group_id/vendors/:vendor_id/profile
    def update
      if @vendor_profile.update(vendor_profile_params)
        render json: format_vendor_profile(@vendor_profile), status: :ok
      else
        render json: { error: 'Validation Error', errors: @vendor_profile.errors.full_messages },
               status: :unprocessable_content
      end
    end

    private

    def set_group
      @group = Group.find(params[:group_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Group not found.' }, status: :not_found
    end

    def set_vendor_affiliate
      @vendor_affiliate = @group.group_affiliate
      @vendor_affiliate = nil unless @vendor_affiliate&.vendor_id == current_user.id
    end

    def authorize_group_vendor!
      unless @vendor_affiliate
        render json: { error: 'Forbidden', message: 'Only the group vendor can perform this action.' },
               status: :forbidden
      end
    end

    def set_vendor_profile
      @vendor_profile = @group.vendor_profiles
                             .find_or_initialize_by(vendor_id: current_user.id) do |profile|
        profile.group_id = @group.id
      end
    end

    def vendor_profile_params
      params.require(:vendor_profile).permit(:image_path, :vendor_name, :vendor_description)
    end

    def format_vendor_profile(profile)
      profile.as_json(
        only: [:id, :group_id, :vendor_id, :image_path, :vendor_name, :vendor_description, :created_at, :updated_at]
      )
    end
  end
end
