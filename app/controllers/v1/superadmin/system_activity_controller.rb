# frozen_string_literal: true

module V1
  module Superadmin
    class SystemActivityController < ApplicationController
      include Authenticable

      before_action :ensure_superadmin!

      # GET /v1/superadmin/system_activity
      def index
        # 1. Active Users Calculation
        # Consider users active if they made any authenticated request in the last 15 minutes
        cutoff_15m = 15.minutes.ago
        cutoff_10m = 10.minutes.ago
        cutoff_5m  = 5.minutes.ago
        cutoff_2m  = 2.minutes.ago

        # Active user sessions with recent activity
        active_sessions = UserSession.active
                                     .where('last_used_at >= ?', cutoff_15m)
                                     .includes(:user)
                                     .order(last_used_at: :desc)

        # Unique active users
        active_users_by_id = {}
        active_sessions.each do |session|
          next unless session.user
          next if active_users_by_id.key?(session.user_id)

          active_users_by_id[session.user_id] = {
            session: session,
            user: session.user
          }
        end

        # Also capture any users with recorded activity in the last 15m (covers API keys or un-synced sessions)
        recent_activity_user_ids = UserActivity.where('created_at >= ?', cutoff_15m).distinct.pluck(:user_id)
        missing_user_ids = recent_activity_user_ids - active_users_by_id.keys
        if missing_user_ids.any?
          User.where(id: missing_user_ids).find_each do |user|
            active_users_by_id[user.id] = {
              session: nil,
              user: user
            }
          end
        end

        # Latest activity per active user
        active_user_ids = active_users_by_id.keys
        latest_activities = if active_user_ids.any?
                              UserActivity.where(user_id: active_user_ids)
                                          .where('created_at >= ?', cutoff_15m)
                                          .order(created_at: :desc)
                                          .group_by(&:user_id)
                            else
                              {}
                            end

        active_users_data = active_users_by_id.map do |user_id, entry|
          user = entry[:user]
          session = entry[:session]
          latest_act = latest_activities[user_id]&.first

          last_time = [session&.last_used_at, latest_act&.created_at].compact.max || Time.current

          {
            id: user.id,
            email: user.email,
            full_name: user.full_name.presence || user.email,
            role: user.role,
            is_current_user: (user.id == @current_user.id),
            last_active_at: last_time,
            seconds_ago: (Time.current - last_time).to_i.clamp(0, Float::INFINITY).to_i,
            status: (last_time >= cutoff_2m ? 'active' : 'idle'), # active < 2m, idle 2-15m
            latest_activity: latest_act ? {
              action_name: latest_act.action_name,
              category: latest_act.category,
              http_method: latest_act.http_method,
              path: latest_act.path,
              created_at: latest_act.created_at
            } : nil
          }
        end

        # Sort by most recent activity first
        active_users_data.sort_by! { |u| u[:seconds_ago] }

        include_superadmin = ActiveRecord::Type::Boolean.new.cast(params[:include_superadmin])
        superadmin_emails = UserActivityRecorder.superadmin_emails

        # Non-superadmin active users count (to know if real users are impacted)
        other_users = active_users_data.reject { |u| u[:is_current_user] || superadmin_emails.include?(u[:email].to_s.downcase) }
        other_users_last_5m = other_users.count { |u| u[:seconds_ago] <= 300 }
        other_users_last_10m = other_users.count { |u| u[:seconds_ago] <= 600 }

        # Filter active users list: exclude superadmin by default unless chosen
        displayed_active_users = include_superadmin ? active_users_data : other_users

        # Determine deployment readiness
        deployment_status = if other_users_last_5m.positive?
                              {
                                status: 'critical', # Red
                                label: 'Caution: Users Active Now',
                                message: "#{other_users_last_5m} other #{'user'.pluralize(other_users_last_5m)} actively interacting within the last 5 minutes.",
                                safe_to_deploy: false
                              }
                            elsif other_users_last_10m.positive?
                              {
                                status: 'warning', # Yellow
                                label: 'Moderate: Recent Activity',
                                message: "#{other_users_last_10m} other #{'user'.pluralize(other_users_last_10m)} active within the last 10 minutes. Deploy with caution.",
                                safe_to_deploy: false
                              }
                            else
                              {
                                status: 'safe', # Green
                                label: 'Safe to Deploy',
                                message: 'No other user activity in the last 10 minutes. Safe to proceed with deployment.',
                                safe_to_deploy: true
                              }
                            end

        # 2. Activity Logs (Past 3 Days)
        activities_scope = UserActivity.within_days(3).includes(:user).recent
        activities_scope = activities_scope.for_user(params[:user_id]) if params[:user_id].present?
        activities_scope = activities_scope.for_category(params[:category]) if params[:category].present?

        # Exclude superadmin actions by default unless explicitly chosen
        unless include_superadmin
          activities_scope = activities_scope.joins(:user).where.not(users: { email: superadmin_emails })
        end

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 30).to_i
        total_activities = activities_scope.count
        activities = activities_scope.offset((page - 1) * per_page).limit(per_page)

        activities_data = activities.map do |act|
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
            http_method: act.http_method,
            path: act.path,
            details: act.details,
            ip_address: act.ip_address,
            created_at: act.created_at
          }
        end

        render json: {
          success: true,
          deployment_status: deployment_status,
          active_users_summary: {
            total_active_15m: displayed_active_users.count,
            other_active_15m: other_users.count,
            active_last_5m: other_users_last_5m
          },
          active_users: displayed_active_users,
          audit_logs: {
            records: activities_data,
            meta: {
              current_page: page,
              per_page: per_page,
              total_count: total_activities,
              total_pages: (total_activities.to_f / per_page).ceil
            }
          }
        }
      end

      private

      def ensure_superadmin!
        return if @current_user && UserActivityRecorder.superadmin?(@current_user)

        render json: {
          success: false,
          message: 'Forbidden: Superadmin access required'
        }, status: :forbidden
      end


    end
  end
end
