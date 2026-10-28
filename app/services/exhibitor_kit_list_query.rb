# frozen_string_literal: true

# One place that decides which exhibitor kits an organizer's filters match, so the paginated
# Exhibitors table and the "apply to all matching" bulk tag action can never disagree.
#
# Recognised params: q, payment_status, booth_type, booth_pricing, zone (`__unassigned__`
# for kits without a zone) and tags_status (none | partial | complete).
class ExhibitorKitListQuery
  TAGS_STATUSES = %w[none partial complete].freeze

  def initialize(event, params)
    @event = event
    @params = params
  end

  # Every kit of an exhibitor that has at least one live booking, narrowed by the filters.
  def scope
    scope = ExhibitorKit.joins(event_vendor: :vendor)
                        .where(event_vendors: { event_id: @event.id, type: 'Exhibitor' })
                        .where(event_vendor_id: @event.exhibitors.with_active_kit.select(:id))
    scope = scope.where(payment_status: @params[:payment_status]) if ExhibitorKit.payment_statuses.key?(@params[:payment_status])
    scope = scope.where(booth_type: @params[:booth_type]) if @params[:booth_type].present?
    scope = filter_by_price(scope)
    scope = filter_by_search(scope)
    filter_by_tags(scope)
  end

  # Tags collected vs. included over the matching kits, plus how many were taken beyond the
  # included count. Cancelled kits can't collect, so they don't count.
  def tag_totals
    live = scope.where.not(booking_status: :cancelled).reorder(nil)
    per_kit = @event.exhibitor_tags_per_kit.to_i
    {
      collected: live.sum(Arel.sql("LEAST(exhibitor_kits.tags_collected, #{per_kit})")),
      entitled: live.count * per_kit,
      extra: live.sum(Arel.sql("GREATEST(exhibitor_kits.tags_collected - #{per_kit}, 0)"))
    }
  end

  private

  def filter_by_price(scope)
    if @params[:booth_pricing].present?
      scope = scope.joins(:exhibitor_booth_price).where(exhibitor_booth_prices: { label: @params[:booth_pricing] })
    end
    return scope if @params[:zone].blank?

    if @params[:zone] == '__unassigned__'
      scope.left_joins(exhibitor_booth_price: :exhibitor_zone).where(exhibitor_zones: { id: nil })
    else
      scope.joins(exhibitor_booth_price: :exhibitor_zone).where(exhibitor_zones: { zone: @params[:zone] })
    end
  end

  def filter_by_search(scope)
    return scope if @params[:q].blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].strip)}%"
    scope.where(
      'exhibitor_kits.company_name ILIKE :t OR exhibitor_kits.booth_number ILIKE :t OR users.full_name ILIKE :t',
      t: term
    )
  end

  def filter_by_tags(scope)
    return scope unless TAGS_STATUSES.include?(@params[:tags_status])

    per_kit = @event.exhibitor_tags_per_kit.to_i
    case @params[:tags_status]
    when 'none' then scope.where(tags_collected: 0)
    when 'partial' then scope.where('exhibitor_kits.tags_collected > 0 AND exhibitor_kits.tags_collected < ?', per_kit)
    else scope.where('exhibitor_kits.tags_collected > 0 AND exhibitor_kits.tags_collected >= ?', per_kit)
    end
  end
end
