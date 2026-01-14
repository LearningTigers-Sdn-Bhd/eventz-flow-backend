# app/controllers/v1/resources_leads_controller.rb
class V1::ResourcesLeadsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create]
  before_action :set_lead, only: [:show]

  # GET /v1/resources/leads
  def index
    authorize ResourceLead
    # Fetch leads for gated resources only, ordered by creation date
    @leads = policy_scope(ResourceLead)
      .joins(:resource)
      .where(resources: { is_gated: true })
      .includes(:resource)
      .order(created_at: :desc)

    # Paginate the results
    pagy, paginated_leads = pagy(@leads, limit: params[:per_page] || 15)

    # Format the response with resource information
    formatted_leads = paginated_leads.map do |lead|
      lead.as_json.merge(
        resource: {
          id: lead.resource.id,
          title: lead.resource.title,
          slug: lead.resource.slug
        }
      )
    end

    success_response(data: formatted_leads, pagination: pagy_metadata(pagy))
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

    # Get total gated resources count and filled count
    total_gated_resources = Resource.where(is_gated: true).count
    gated_resources_with_leads = Resource
      .where(is_gated: true)
      .joins(:resource_leads)
      .distinct
      .count

    # Get total leads count
    total_leads = ResourceLead.count

    # Get leads grouped by week (last 12 weeks)
    twelve_weeks_ago = 12.weeks.ago.beginning_of_week
    leads_by_week = ResourceLead
      .where('created_at >= ?', twelve_weeks_ago)
      .group(Arel.sql("DATE_TRUNC('week', created_at)"))
      .order(Arel.sql("DATE_TRUNC('week', created_at)"))
      .count

    # Format week data with ISO week format
    date_data = leads_by_week.map do |week_start, count|
      {
        week: week_start.strftime('%Y-W%V'),
        lead_counts: count
      }
    end

    # Get top 10 countries
    country_data = ResourceLead
      .where.not(country: [nil, ''])
      .group(:country)
      .count
      .sort_by { |_, count| -count }
      .first(10)
      .map { |name, count| { name: name, count: count } }

    # Get top 10 job titles
    job_data = ResourceLead
      .where.not(job_title: [nil, ''])
      .group(:job_title)
      .count
      .sort_by { |_, count| -count }
      .first(10)
      .map { |title, count| { title: title, count: count } }

    metrics_data = {
      resources: {
        count: total_gated_resources,
        filled: gated_resources_with_leads
      },
      total_leads: total_leads,
      date: date_data,
      country: country_data,
      job: job_data
    }

    success_response(data: metrics_data)
  end

  private

  def set_lead
    @lead = ResourceLead.find(params[:id])
  end

  def lead_params
    params.require(:resource_lead).permit(:resource_id, :email, :name, :phone, :company_name, :state, :country, :job_title)
  end
end
