# app/controllers/v1/vendor_dashboard_controller.rb
module V1
  class VendorDashboardController < ApplicationController
    # GET /v1/vendor/dashboard
    def index
      # Get events where current user is a vendor
      event_vendors = EventVendor.where(vendor_id: current_user.id).includes(:event)

      events_data = event_vendors.map do |ev|
        event = ev.event

        # Stamp count for this vendor
        stamp_count = VisitorVendorStamp.joins(:visitor)
                                        .where(event_vendor: ev)
                                        .where(visitors: { event_id: event.id })
                                        .count

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
          stamp_count: stamp_count,
          total_vouchers: total_vouchers,
          total_redeemed: total_redeemed,
          redemption_rate: total_vouchers.zero? ? 0 : (total_redeemed.to_f / total_vouchers * 100).round(1)
        }
      end

      # Aggregate totals
      render json: {
        summary: {
          total_events: events_data.count,
          active_events: events_data.count { |e| e[:status] == 'published' },
          total_stamps: events_data.sum { |e| e[:stamp_count] },
          total_vouchers: events_data.sum { |e| e[:total_vouchers] },
          total_redeemed: events_data.sum { |e| e[:total_redeemed] }
        },
        events: events_data
      }
    end
  end
end
