# frozen_string_literal: true

module V1
  class ContractorDashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_exhibition_contractor

    # GET /v1/contractor/dashboard
    def index
      profile = current_user.exhibition_contractor_profile

      if profile.nil?
        return render json: empty_dashboard_response, status: :ok
      end

      events_data = build_events_data(profile)
      summary = build_summary(events_data)

      render json: { summary: summary, events: events_data }, status: :ok
    end

    private

    def ensure_exhibition_contractor
      return if current_user.exhibition_contractor?

      render json: { error: 'Access denied. Exhibition contractor role required.' },
             status: :forbidden
    end

    def empty_dashboard_response
      {
        summary: {
          total_events: 0,
          active_events: 0,
          total_exhibitors: 0,
          total_received_amount: 0.0,
          pending_payments_count: 0,
          verified_payments_count: 0
        },
        events: []
      }
    end

    def build_events_data(profile)
      assigned_events = Event
                        .joins(:event_exhibition_contractor)
                        .where(event_exhibition_contractors: { exhibition_contractor_profile_id: profile.id })
                        .includes(:event_exhibition_contractor)

      assigned_events.map { |event| build_event_data(event) }
    end

    def build_event_data(event)
      payments = payments_for_event(event)
      exhibitors_count = exhibitors_count_for_event(event)

      {
        id: event.id,
        title: event.title,
        status: event.status,
        start_date: event.start_date&.iso8601,
        end_date: event.end_date&.iso8601,
        exhibitors_count: exhibitors_count,
        total_received_amount: payments.verified.sum(:amount).to_f,
        pending_payments_count: payments.pending.count + payments.submitted.count,
        verified_payments_count: payments.verified.count
      }
    end

    def payments_for_event(event)
      ExhibitorKitPayment
        .joins(exhibitor_kit: :event_vendor)
        .where(payee_id: current_user.id)
        .where(event_vendors: { event_id: event.id })
    end

    def exhibitors_count_for_event(event)
      ExhibitorKit
        .joins(event_vendor: :event)
        .joins(exhibitor_kit_payments: {})
        .where(event_vendors: { event_id: event.id })
        .where(exhibitor_kit_payments: { payee_id: current_user.id })
        .distinct
        .count
    end

    def build_summary(events_data)
      {
        total_events: events_data.count,
        active_events: events_data.count { |e| e[:status] == 'published' },
        total_exhibitors: events_data.sum { |e| e[:exhibitors_count] },
        total_received_amount: events_data.sum { |e| e[:total_received_amount] },
        pending_payments_count: events_data.sum { |e| e[:pending_payments_count] },
        verified_payments_count: events_data.sum { |e| e[:verified_payments_count] }
      }
    end
  end
end
