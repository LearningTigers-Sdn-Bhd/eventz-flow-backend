# app/controllers/v1/resources_leads_controller.rb
class V1::ResourcesLeadsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create]
  before_action :set_lead, only: [:show]

  # GET /v1/resources/leads
  def index
    authorize ResourceLead
    @leads = policy_scope(ResourceLead).order(created_at: :desc)
    success_response(data: @leads)
  end

  # GET /v1/resources/leads/:id
  def show
    authorize @lead
    success_response(data: @lead)
  end

  # POST /v1/resources/leads
  def create
    authorize ResourceLead
    # This action is public, but we still check policy for consistency.
    # The `create?` method in the policy returns true.

    @lead = ResourceLead.new(lead_params)
    @lead.ip_address = request.remote_ip
    @lead.accessed_at = Time.current

    if @lead.save
      success_response(data: @lead, status: :created, message: 'Successfully submitted')
    else
      error_response(errors: format_validation_errors(@lead))
    end
  end

  # GET /v1/resources/leads/metrics
  def metrics
    authorize ResourceLead
    # Simple metric for now, can be expanded.
    total_leads = ResourceLead.count
    leads_by_country = ResourceLead.group(:country).count
    
    metrics_data = {
      total_leads: total_leads,
      leads_by_country: leads_by_country
    }

    success_response(data: metrics_data)
  end

  private

  def set_lead
    @lead = ResourceLead.find(params[:id])
  end

  def lead_params
    params.require(:lead).permit(:email, :name, :phone, :company_name, :state, :country, :job_title)
  end
end
