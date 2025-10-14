# app/policies/event_policy.rb
class EventPolicy < ApplicationPolicy
	def create?
		user.present? && user.is_superadmin?
	end

	def show?
		user.is_superadmin? ||
		record.user == user ||
		EventAdmin.exists?(user: user, event: record) ||
		EventTeamMember.exists?(user: user, event: record)
	end

	def update?
		user.is_superadmin? ||
		record.user == user ||
		EventAdmin.exists?(user: user, event: record)
	end

	def destroy?
		user.is_superadmin? ||
		record.user == user
	end

	class Scope < Scope
		def resolve
			user_id = user.id
			creator_condition = "events.user_id = :user_id"
			admin_subquery = EventAdmin.where(user_id: user_id).select(:event_id)
			admin_condition = "events.id IN (#{admin_subquery.to_sql})"
			team_member_subquery = EventTeamMember.where(user_id: user_id).select(:event_id)
			team_member_condition = "events.id IN (#{team_member_subquery.to_sql})"

			scope
				.where("#{creator_condition} OR #{admin_condition} OR #{team_member_condition}", user_id: user_id)
				.distinct
		end
	end
end