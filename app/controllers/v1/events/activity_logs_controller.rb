# frozen_string_literal: true

module V1
  module Events
    class ActivityLogsController < ApplicationController
      before_action :set_event

      def index
        authorize @event, :view_activity_log?

        scope = UserActivity.where(event_id: @event.id).includes(:user).recent
        scope = apply_date_range(scope)
        scope = scope.where.not(http_method: 'GET')
        scope = scope.for_category(params[:category]) if params[:category].present?
        scope = scope.where.not(category: %w[groups users api_keys payment_details auth])
        unless @current_user.is_org_owner?
          scope = scope.joins(:user).where.not(users: { role: User.roles[:org_owner] })
        end
        scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
        scope = scope.where(result: params[:result]) if %w[success failed].include?(params[:result])
        if params[:q].present?
          term = "%#{params[:q].strip}%"
          scope = scope.joins(:user)
                       .where('user_activities.action_name ILIKE :term OR users.full_name ILIKE :term OR users.email ILIKE :term', term: term)
        end

        page = [(params[:page] || 1).to_i, 1].max
        per_page = (params[:per_page] || 30).to_i.clamp(1, 100)
        total_activities = scope.count
        activities = scope.offset((page - 1) * per_page).limit(per_page).to_a
        ticket_attendees = ticket_attendees_for(activities)

        records = activities.map do |act|
          {
            id: act.id,
            user: {
              id: act.user_id,
              email: act.user.email,
              full_name: act.user.full_name.presence || act.user.email,
              role: act.user.role
            },
            category: act.category,
            action_name: act.action_name,
            result: act.result,
            error_message: act.error_message,
            details: details_with_ticket_attendee(act.details, ticket_attendees),
            created_at: act.created_at
          }
        end

        render json: {
          success: true,
          audit_logs: {
            records: records,
            meta: {
              current_page: page,
              per_page: per_page,
              total_count: total_activities,
              total_pages: (total_activities.to_f / per_page).ceil
            }
          }
        }
      end

      def destroy_all
        authorize @event, :clear_activity_log?

        UserActivity.where(event_id: @event.id).delete_all

        render json: { success: true }
      end

      private

      def set_event
        @event = Event.friendly.find(params[:event_id])
      end

      # Retention only keeps 90 days of rows, so an explicit range narrows
      # within that window rather than extending past it.
      def apply_date_range(scope)
        from_date = parse_date(params[:from_date])
        to_date = parse_date(params[:to_date])
        return scope.within_days(90) if from_date.blank? && to_date.blank?

        scope = scope.where('user_activities.created_at >= ?', from_date.beginning_of_day) if from_date
        scope = scope.where('user_activities.created_at <= ?', to_date.end_of_day) if to_date
        scope
      end

      def parse_date(date_string)
        return nil if date_string.blank?
        Date.parse(date_string)
      rescue ArgumentError
        nil
      end

      def ticket_attendees_for(activities)
        public_ids = activities.filter_map do |activity|
          resource = activity.details.is_a?(Hash) ? activity.details['resource'] : nil
          next unless resource.is_a?(Hash)
          next unless resource['type'].to_s.casecmp('ticket').zero?
          next if resource['attendee'].present?

          resource['id'].to_s.presence
        end.uniq
        return {} if public_ids.empty?

        Ticket.with_deleted.where(event_id: @event.id, public_id: public_ids)
              .pluck(:public_id, :attendee_name, :attendee_email)
              .each_with_object({}) do |(public_id, name, email), attendees|
                details = { 'name' => name, 'email' => email }.compact
                attendees[public_id.to_s] = details if details.present?
              end
      end

      def details_with_ticket_attendee(details, ticket_attendees)
        return details unless details.is_a?(Hash)

        resource = details['resource']
        return details unless resource.is_a?(Hash)
        return details unless resource['type'].to_s.casecmp('ticket').zero?

        attendee = ticket_attendees[resource['id'].to_s]
        return details if attendee.blank?

        details.merge('resource' => resource.merge('attendee' => attendee))
      end
    end
  end
end
