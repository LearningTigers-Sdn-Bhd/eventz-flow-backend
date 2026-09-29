# app/controllers/v1/vendor_dashboard_controller.rb
module V1
  class VendorDashboardController < ApplicationController
    # GET /v1/vendor/dashboard
    def index
      # Get events where current user is a vendor
      event_vendors = EventVendor.where(vendor_id: current_user.id).includes(:event)
      event_vendor_event_ids = event_vendors.map(&:event_id)

      events_data = event_vendors.map do |ev|
        event = ev.event
        next unless event

        # Lead count for this vendor
        lead_count = EventLead.where(event_vendor: ev).count

        # Voucher stats for this vendor (exclude unlimited vouchers from total count)
        vouchers = Voucher.where(event_id: event.id, vendor_id: current_user.id)
        total_vouchers = vouchers.where(is_unlimited: false).sum(:total_redemption_available)
        total_redeemed = VoucherRedemptionLog.joins(:voucher)
                                             .where(vouchers: { event_id: event.id, vendor_id: current_user.id })
                                             .count

        {
          id: event.id,
          title: event.title,
          status: event.status,
          use_ticket: event.use_ticket,
          start_date: event.start_date,
          end_date: event.end_date,
          event_vendor_id: ev.id,
          is_business_host_only: false,
          lead_count: lead_count,
          total_vouchers: total_vouchers,
          total_redeemed: total_redeemed,
          redemption_rate: total_vouchers.zero? ? 0 : (total_redeemed.to_f / total_vouchers * 100).round(1)
        }
      end.compact

      # Include events where current user is a business host only (no EventVendor record)
      host_event_ids = (current_user.event_assignments.where(role: :business_host).pluck(:event_id) +
                        current_user.business_host_assignments.pluck(:event_id)).uniq
      host_only_event_ids = host_event_ids - event_vendor_event_ids

      if host_only_event_ids.present?
        host_only_events = Event.where(id: host_only_event_ids)
        host_only_events_data = host_only_events.map do |event|
          {
            id: event.id,
            title: event.title,
            status: event.status,
            use_ticket: event.use_ticket,
            start_date: event.start_date,
            end_date: event.end_date,
            event_vendor_id: nil,
            is_business_host_only: true,
            lead_count: 0,
            total_vouchers: 0,
            total_redeemed: 0,
            redemption_rate: 0
          }
        end
        events_data.concat(host_only_events_data)
      end

      # Sort events: active/upcoming first, latest date on top, past events below
      now = Time.current
      events_data.sort_by! do |e|
        is_past = e[:end_date].present? && e[:end_date].to_time.end_of_day < now
        [is_past ? 1 : 0, -(e[:start_date]&.to_time&.to_i || 0), -e[:id]]
      end

      # Aggregate totals
      render json: {
        summary: {
          total_events: events_data.count,
          active_events: events_data.count { |e| e[:status] == 'published' },
          total_leads: events_data.sum { |e| e[:lead_count] },
          total_vouchers: events_data.sum { |e| e[:total_vouchers] },
          total_redeemed: events_data.sum { |e| e[:total_redeemed] }
        },
        events: events_data
      }
    end
  end
end
