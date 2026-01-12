module V1
  class SponsorsController < ApplicationController
    before_action :set_sponsor, only: [:show, :update, :destroy]
    before_action :authorize_sponsor, only: [:show, :update, :destroy]

    # GET /v1/sponsors
    def index
      authorize Sponsor
      @sponsors = policy_scope(Sponsor)
      
      # Optional: filtering by group_id if passed (though policy scope usually handles tenancy)
      if params[:group_id].present?
        @sponsors = @sponsors.where(group_id: params[:group_id])
      end

      render json: @sponsors
    end

    # GET /v1/sponsors/:id
    def show
      render json: @sponsor.as_json(
        include: {
          event_sponsorships: {
            include: {
              event: { only: [:id, :title, :start_date, :end_date, :status] }
            }
          }
        },
        methods: [:total_sponsorship_count, :total_pledged_amount, :total_received_amount]
      )
    end

    # POST /v1/sponsors
    def create
      authorize Sponsor
      @sponsor = Sponsor.new(sponsor_params)
      @sponsor.created_by = current_user
      
      # Derive group_id if not present (Multi-tenant support)
      if @sponsor.group_id.blank?
        @sponsor.group = Group.visible_to(current_user).first
      end

      if @sponsor.save
        render json: @sponsor, status: :created
      else
        render json: @sponsor.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/sponsors/:id
    def update
      if @sponsor.update(sponsor_params)
        render json: @sponsor
      else
        render json: @sponsor.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/sponsors/:id
    def destroy
      @sponsor.soft_delete
      head :no_content
    end

    # GET /v1/sponsors/lookup
    def lookup
      authorize Sponsor, :lookup?
      @sponsors = policy_scope(Sponsor)

      if params[:search].present?
        term = "%#{params[:search]}%"
        @sponsors = @sponsors.where("name ILIKE ?", term)
      end

      render json: @sponsors.select(:id, :name, :logo_path, :industry)
    end

    private

    def set_sponsor
      @sponsor = Sponsor.find(params[:id])
    end

    def authorize_sponsor
      authorize @sponsor
    end

    def sponsor_params
      params.require(:sponsor).permit(
        :group_id,
        :name,
        :website,
        :industry,
        :default_email,
        :default_whatsapp,
        :default_contact_name,
        :default_contact_position,
        :notes,
        :logo_path,
        :is_active
      )
    end
  end
end
