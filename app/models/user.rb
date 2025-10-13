class User < ApplicationRecord
	has_secure_password

	enum :role, { superadmin: 0, admin: 1, team_member: 2, participant: 3 }
	validates :email, presence: true, uniqueness: { case_sensitive: false }

	# Events assigned to User as an Admin
	has_many :event_admins, dependent: :destroy
	has_many :assigned_events, through: :event_admins, source: :event

	# Events where User is a Team Member
	has_many :event_team_members, dependent: :destroy
	has_many :events_managed, through: :event_team_members, source: :event

	def is_superadmin?
		role == 'superadmin'
	end

	def is_admin?
		role.in?(['superadmin', 'admin'])
	end

	def is_team_member?
		role == 'team_member'
	end
end