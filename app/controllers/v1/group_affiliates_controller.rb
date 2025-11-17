module V1
  class GroupAffiliatesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_group

    # GET /v1/groups/:group_id/affiliates
    def index
      authorize @group, policy_class: GroupPolicy

      @affiliates = @group.group_affiliates.includes(:vendor)
      render json: @affiliates.map { |affiliate| format_affiliate(affiliate) }
    end

    # POST /v1/groups/:group_id/affiliates
    def create
      authorize @group, policy_class: GroupPolicy
      authorize GroupAffiliate.new(group: @group), policy_class: GroupAffiliatePolicy

      vendor = User.find(group_affiliate_params[:vendor_id])

      @affiliate = @group.group_affiliates.build(vendor: vendor)

      if @affiliate.save
        render json: format_affiliate(@affiliate), status: :created
      else
        error_response(
          message: 'Validation failed',
          errors: format_validation_errors(@affiliate),
          status: :unprocessable_content
        )
      end
    end

    # DELETE /v1/groups/:group_id/affiliates/:id
    def destroy
      @affiliate = @group.group_affiliates.find(params[:id])

      authorize @affiliate, policy_class: GroupAffiliatePolicy

      if @affiliate.destroy
        head :no_content
      else
        error_response(
          message: 'Failed to remove vendor affiliate',
          errors: format_validation_errors(@affiliate),
          status: :unprocessable_content
        )
      end
    rescue ActiveRecord::RecordNotFound
      error_response(message: 'Vendor affiliate not found', status: :not_found)
    end

    private

    def set_group
      @group = Group.find(params[:group_id])
    rescue ActiveRecord::RecordNotFound
      error_response(message: 'Group not found', status: :not_found)
    end

    def group_affiliate_params
      params.require(:group_affiliate).permit(:vendor_id)
    end

    def format_affiliate(affiliate)
      {
        id: affiliate.id,
        group_id: affiliate.group_id,
        vendor_id: affiliate.vendor_id,
        vendor: {
          id: affiliate.vendor.id,
          email: affiliate.vendor.email,
          full_name: affiliate.vendor.full_name
        },
        created_at: affiliate.created_at,
        updated_at: affiliate.updated_at
      }
    end
  end
end
